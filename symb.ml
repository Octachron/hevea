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

let header = "$Id: symb.ml,v 1.17 1999-05-21 12:54:17 maranget Exp $" 
open Parse_opts

let tr = function
  "<" -> "<"
| ">" -> ">"
| "\\{" -> "{"
| "\\}" -> "}"
| s   -> s
;;
let put_delim skip put d n =

  let  put_skip s = put s ; skip () ; in

  let rec do_rec s i =
    if i >= 1 then begin
      put_skip s;
      do_rec s (i-1)
    end

  and do_bis s i =
    if i>= 2 then begin
      put_skip s ;
      do_bis s (i-1)
    end else
      put s in

  if not !symbols || n=1 then
    let d = tr d in
    do_bis d n
  else begin
    put "<FONT FACE=symbol>\n" ;
    if d = "(" then begin
      put_skip "�" ;
      do_rec "�" (n-2) ;
      put "�"
    end else if d=")" then begin
      put_skip "�" ;
      do_rec "�" (n-2) ;
      put "�"
    end else if d = "[" then begin
      put_skip "�" ; 
      do_rec "�" (n-2) ;
      put "�"
    end else if d="]" then begin
      put_skip "�" ; 
      do_rec "�" (n-2) ;
      put "�"
   end else if d = "\\lfloor" then begin
      do_rec "�" (n-1) ;
      put "�"
    end else if d="\\rfloor" then begin
      do_rec "�" (n-1) ;
      put "�"
    end else if d = "\\lceil" then begin
      put_skip "�" ; 
      do_bis "�" (n-1)
    end else if d="\\rceil" then begin
      put_skip "�" ; 
      do_bis "�" (n-1)
    end else if d="|" then begin
      do_bis "�" n
    end else if d="\\|" then begin
      do_bis "��" n
    end else if d = "\\{" then begin
      put_skip "�" ; 
      do_rec "�" ((n-3)/2) ;
      put_skip "�" ; 
      do_rec "�" ((n-3)/2) ;
      put "�"     
    end else if d = "\\}" then begin
      put_skip "�" ; 
      do_rec "�" ((n-3)/2) ;
      put_skip "�" ; 
      do_rec "�" ((n-3)/2) ;
      put "�"     
    end ;
    put "</FONT>"
  end
;;


   
  
