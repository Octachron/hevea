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

let header =  "$Id: element.ml,v 1.2 2002-06-04 11:37:05 maranget Exp $"
(* For text-level elements *)
type text =
  Style of string
| Font of int
| Color of string
| StyleAttr of string * string
let pretty_text = function
  Style s -> "Style: "^s
| Font i  -> "Font size: "^string_of_int i
| Color s  -> "Font color: "^s
| StyleAttr (t,a) -> "Style with attributes: "^t^" ["^a^"]"
;;
