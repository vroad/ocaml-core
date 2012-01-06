open Core.Std
open Import

let debug = Debug.debug

module Fd = Raw_fd

type t =
  { pipe : Fd.t Read_write.t;
    (* [already_interrupted] keeps track of whether we've already interrupted since the
       most recent call to [clear], and if so, avoid writing to the pipe again.
       [already_interrupted] does not exactly track the state of [pipe].  It is possible
       for [already_interrupted] to be false and for the [pipe] to be nonempty.  The key
       property is that if [already_interrupted] is true then [pipe] is nonempty *)
    mutable already_interrupted : bool;
    clearbuffer : string sexp_opaque;
  }
with sexp_of

let read_fd t = Read_write.get t.pipe `Read

let create fd_by_descr =
  let (pipe_read, pipe_write) = Unix.pipe () in
  let pipe_read =
    Fd_by_descr.create_fd fd_by_descr Fd.Kind.Fifo pipe_read
      ~name:"interruptor_pipe_read"
  in
  let pipe_write =
    Fd_by_descr.create_fd fd_by_descr Fd.Kind.Fifo pipe_write
      ~name:"interruptor_pipe_write"
  in
  { pipe = Read_write.create ~read:pipe_read ~write:pipe_write;
    already_interrupted = false;
    clearbuffer = String.make 1024 ' ';
  }
;;

  (* [thread_safe_interrupt]
     As the name implies, it is safe to call from any thread; [thread_safe_interrupt] does
     not assume the scheduler lock is held, although it is fine if it is.  Because of
     OCaml's compilation, the test-and-set of [t.already_interrupted] is atomic, so
     we will only ever write one byte to the pipe before it is cleared. *)
let thread_safe_interrupt t =
  if debug then Debug.print "thread_safe_interrupt";
    (* BEGIN ATOMIC *)
  if not t.already_interrupted then begin
    t.already_interrupted <- true;
      (* END ATOMIC *)
    if debug then Debug.print "writing to interrupt_pipe_write";
    Fd.syscall_exn (Read_write.get t.pipe `Write) ~nonblocking:true
      (fun file_descr ->
        let module U = Unix in
        try
          ignore (U.write_assume_fd_is_nonblocking file_descr "w")
        with
        | U.Unix_error ((U.EWOULDBLOCK | U.EAGAIN), _, _) -> ())
  end
;;

let clear t =
  if debug then Debug.print "Interruptor.clear";
  Fd.syscall_exn (Read_write.get t.pipe `Read) ~nonblocking:true
    (fun file_descr ->
      let rec loop () =
        let module U = Unix in
        let read_again =
          try
            ignore (U.read_assume_fd_is_nonblocking file_descr
                      t.clearbuffer ~pos:0
                      ~len:(String.length t.clearbuffer) : int);
            true
          with
          | U.Unix_error ((U.EWOULDBLOCK | U.EAGAIN), _, _) -> false
        in
        if read_again then loop ()
      in
      loop ());
  t.already_interrupted <- false;
;;