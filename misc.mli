(***********************************************************************)
(*                                                                     *)
(*                          HEVEA                                      *)
(*                                                                     *)
(*  Luc Maranget, projet PARA, INRIA Rocquencourt                      *)
(*                                                                     *)
(*  Copyright 1998 Institut National de Recherche en Informatique et   *)
(*  Automatique.  Distributed only by permission.                      *)
(*                                                                     *)
(***********************************************************************)

exception Fatal of string
exception NoSupport of string
exception Purposly of string
exception ScanError of string
exception UserError of string
exception EndInput
exception EndDocument
exception Close of string
exception EndOfLispComment of int (* QNC *)

val hot_start : unit -> unit
val verbose : int ref
val readverb : int ref
val silent : bool ref
val column_to_command : string -> string
val warning : string -> unit
val print_verb : int -> string -> unit
val message : string -> unit
val fatal : string -> 'a
val not_supported : string -> 'a
val copy_hashtbl : ('b, 'a) Hashtbl.t -> ('b, 'a) Hashtbl.t -> unit
val clone_hashtbl : ('b, 'a) Hashtbl.t -> ('b, 'a) Hashtbl.t

val start_env : string -> string
val end_env : string -> string

type limits = Limits | NoLimits | IntLimits



