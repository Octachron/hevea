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

let header = "$Id: text.ml,v 1.6 1999-05-11 14:05:53 tessaud Exp $"


open Misc
open Parse_opts
open Latexmacros

exception Error of string;;


let r_quote = String.create 1
;;

let r_translate = String.create 1
;;

let iso_translate = function
  '<' -> "<"
| '>' -> ">"
| '&' -> "&"
| '�' -> " "
| '�' -> "!"
| '�' -> "cent"
| '�' -> "pound"
| '�' -> "curren"
| '�' -> "yen"
| '�' -> "I"
| '�' -> "paragraphe"
| '�' -> "trema"
| '�' -> "copyright"
| '�' -> "a"
| '�' -> "<<"
| '�' -> "not"
| '�' -> "-"
| '�' -> "registered"
| '�' -> "-"
| '�' -> "degre"
| '�' -> "plus ou moins"
| '�' -> "carre"
| '�' -> "cube"
| '�' -> "'"
| '�' -> "mu"
| '�' -> ""
| '�' -> "."
| '�' -> ""
| '�' -> "1"
| '�' -> "eme"
| '�' -> ">>"
| '�' -> "1/4"
| '�' -> "1/2"
| '�' -> "3/4"
| '�' -> "?"
| '�' -> "A"
| '�' -> "A"
| '�' -> "A"
| '�' -> "A"
| '�' -> "A"
| '�' -> "A"
| '�' -> "AE"
| '�' -> "C"
| '�' -> "E"
| '�' | '�' | '�' -> "E"
| '�' | '�' | '�' | '�' -> "I"
| '�' -> "D"
| '�' -> "N"
| '�' | '�' | '�' | '�' | '�' -> "O"
| '�' -> "x"
| '�' -> "0"
| '�' | '�' | '�' | '�' -> "U"
| '�' -> "Y"
| '�' -> "P"
| '�' -> "ss"
| '�' | '�' | '�' | '�' | '�' | '�' -> "a"
| '�' -> "ae"
| '�' -> "c"
| '�' | '�' | '�' | '�' -> "e"
| '�' | '�' | '�' | '�' -> "i"
| '�' -> "o"
| '�' -> "n"
| '�' | '�' | '�' | '�' | '�' -> "o"
| '�' -> "/"
| '�' -> "o"
| '�' | '�' | '�' | '�' -> "u"
| '�' -> "y"
| '�' -> "y"
| '�' -> "y"
| c   -> (r_translate.[0] <- c ; r_translate)
;;

let iso c =
  if !Parse_opts.iso then
    (r_quote.[0]<-c; r_quote)
  else
    iso_translate c
;;


exception Close of string
;;

let failclose s = raise (Close s)
;;


let push s e = s:=e::!s
and pop name s = match !s with
  [] -> raise ( Misc.Fatal ("Empty stack:"^name^" in Text"))
| e::rs -> s:=rs; e
and see_top name s = match !s with
  [] -> raise ( Misc.Fatal ("Empty stack:"^name^" in Text (see)"))
| e::_ -> e
;;


let pretty_stack s =
  prerr_string "|" ;
  List.iter
   (function (s,args,_) ->
     prerr_string ("["^s^"]-{"^args^"} ")) s ;
  prerr_endline "|"
;;

(* Gestion des styles : pas de style en mode texte *)

(* output globals *)
type status = {
    mutable nostyle : bool ;
    mutable pending : env list ;
    mutable active : env list ;
    mutable out : Out.t;
    mutable temp : bool
  };;

let free_list = ref [];;

let out_stack = ref [];;

let pblock () = match !out_stack with
  (s,_,_)::_ -> s
| _ -> ""
and parg () = match !out_stack with
  (_,a,_)::_ -> a
| _ -> ""
;;

let free out =
  out.nostyle<-false;
  out.pending<-[];
  out.active<-[];
  Out.reset out.out;
  free_list := out :: !free_list
;;

let cur_out = ref { nostyle = false;
                    pending=[];
                    active=[];
                    out=Out.create_null();
		    temp=false
};;

let set_out out =  
  !cur_out.out <- out
;;

let newstatus nostyle p a t = match !free_list with
  [] ->
    { nostyle = nostyle;
      pending = p;
      active = a;
      out = Out.create_buff ();
      temp = t;
    } 
| e::reste ->
    free_list:=reste;
    e.nostyle <- nostyle;
    e.pending <- p;
    e.active <- a;
    e.temp <- t;
    assert (Out.is_empty e.out);
    e
;;

type align_t = Left | Center | Right ;;


type flags_t = {
(*    mutable ncols : int;*)
    mutable pending_par : int option;
    mutable empty : bool;
(*    mutable vsize : int;*)
    mutable nitems : int;
    mutable dt : string;
    mutable dcount : string;
    mutable last_closed : string;
    mutable align : align_t;
    mutable in_align : bool;
    mutable hsize : int;
    mutable x : int;
    mutable x_start : int;
    mutable x_end : int;
    mutable last_space : int;
    mutable first_line : int;
    mutable underline : string;
    mutable in_table : bool
  }
;;

let flags = {
(*  ncols = 0;*)
  pending_par = None;
  empty = true;
(*  vsize = 0;*)
  nitems = 0;
  dt = "";
  dcount = "";
  last_closed = "rien";
  align = Left;
  in_align = false;
  hsize = !Parse_opts.width;
  x = 0;
  x_start = 0;
  x_end = !Parse_opts.width - 1;
  last_space = 0;
  first_line = 2;
  underline = "";
  in_table = false
} ;;

let line = String.create (!Parse_opts.width +2);;

let nitems_stack = ref [];;
let dt_stack = ref [];;
let dcount_stack = ref [];;
let x_stack = ref[];;
let line_stack = ref [];;
let align_stack = ref [];;
let in_align_stack = ref [];;
let underline_stack = ref [];;
let in_table_stack = ref [];;

let do_do_put_char c =
  Out.put_char !cur_out.out c;;

let do_do_put  s =
  Out.put !cur_out.out s;;

let do_put_line s =
  (* Ligne a formatter selon flags.align, avec les parametres courants.*)
  (* soulignage eventuel *)
  let soul = ref false in
  for i = 0 to String.length s - 2 do
    soul :=!soul || s.[i] <> ' ';
  done;
  soul := !soul && s<>"\n" && flags.underline <> "";

  let ligne = match flags.align with
  | Left -> s
  | Center ->
      let sp = (flags.hsize - (String.length s -flags.x_start))/2 in
      String.concat "" [String.make sp ' '; s]
  | Right ->
      let sp = flags.hsize - String.length s + flags.x_start in
      String.concat "" [ String.make sp ' '; s]
  in
  if !verbose>3 then prerr_endline ("line :"^ligne);
  do_do_put ligne;


  if !soul then begin
    let souligne =
      let l = String.make (String.length s) ' ' in
      let len = String.length flags.underline in
      if len = 0 then raise (Misc.Fatal ("cannot underline with nothing:#"^String.escaped flags.underline^"#"^(
													       if  (flags.underline <> "") then "true" else "false"
													       )));
      for i = flags.x_start to String.length l -2 do
	l.[i]<-flags.underline.[(i-flags.x_start) mod len]
      done;
      l.[String.length l -1]<-'\n';
      match flags.align with
      | Left -> l
      | Center ->
	  let sp = (flags.hsize - String.length l)/2 -flags.x_start in
	  String.concat "" [String.make sp ' '; l]
      | Right ->
	  let sp = (flags.hsize - String.length l) - flags.x_start in
	  String.concat "" [ String.make sp ' '; l]
    in
    if !verbose >3 then prerr_endline ("line underlined:"^souligne); 
 
    do_do_put souligne;
  end
;;

let do_flush () =
  if !verbose>3 then prerr_endline ("flush :"^line);
  do_put_line (String.sub line 0 (flags.x +1)) ;
  flags.x <- -1;
;;
  
let do_put_char2 c =
  if !verbose >3 then
    prerr_endline ("caracters read :"^Char.escaped c^", x="^string_of_int flags.x^", length ="^string_of_int (flags.hsize));

  if c=' ' then  flags.last_space <- flags.x;
  if flags.x =(-1) then begin
    (* La derniere ligne finissait un paragraphe : on indente *)
    flags.x<-flags.x_start + flags.first_line;   
    for i = 0 to flags.x-1 do
      line.[i]<-' ';
    done;
    flags.last_space<-flags.x-1;
  end;
  line.[flags.x]<-c;
  if c='\n' then begin
	(* Ligne prete *)
    if !verbose>2 then
      prerr_endline("line not cut :"^line);
    do_put_line (String.sub line 0 (flags.x +1));
    flags.x <- -1;
  end else
    flags.x<-flags.x + 1;
  if flags.x>flags.x_end then begin (* depassement de ligne *)
    if (flags.x - flags.last_space) >= flags.hsize then begin
	  (* On coupe brutalement le mot trop long *)
      if !verbose >2 then
	prerr_endline ("line cut :"^line);
      line.[flags.x+1]<-'\n';
	  (* La ligne est prete et complete*)
      do_put_line (String.sub line 0 (flags.hsize+1));
      for i = 0 to flags.x_start-1 do line.[i]<-' ' done;
      line.[flags.x_start]<-c;
      flags.x<-flags.x_start + 1;
      flags.last_space<-flags.x_start-1;
    end else begin
      if !verbose > 2 then begin
	prerr_endline ("Line and the beginning of the next word :"^line);
	prerr_endline ("x ="^string_of_int flags.x);
	prerr_endline ("x_start ="^string_of_int flags.x_start);
	prerr_endline ("x_end ="^string_of_int flags.x_end);
	prerr_endline ("hsize ="^string_of_int flags.hsize);
	prerr_endline ("last_space ="^string_of_int flags.last_space);
	prerr_endline ("line size ="^string_of_int (String.length line));
      end;
	  (* On repart du dernier espace *)
      let reste = 
	let len = flags.x - flags.last_space -1 in
	if len = 0 then ""
	else
	  String.sub line (flags.last_space +1) len
      in
	  (* La ligne est prete et incomplete*)
      line.[flags.last_space]<-'\n';
      do_put_line (String.sub line 0 (flags.last_space+1));
      
      for i = 0 to flags.x_start-1 do line.[i]<-' ' done;
      for i = flags.x_start to (flags.x_start+ String.length reste -1) do
	line.[i]<- reste.[i-flags.x_start];
      done;
      flags.x<- flags.x_start + (String.length reste);
      flags.last_space <- flags.x_start-1;
    end;
  end;
;;  

let do_put_char c =
  if !verbose>3 then
    prerr_endline ("put_char:|"^String.escaped (String.make 1 c)^"|");
  if !cur_out.temp || (Out.is_null !cur_out.out) 
  then do_do_put_char c
  else do_put_char2 c
;;

let do_unskip () =
  if !cur_out.temp || (Out.is_null !cur_out.out) then
    Out.unskip !cur_out.out
  else begin
    while flags.x > flags.x_start && line.[flags.x-1] = ' ' do
      flags.x <- flags.x - 1
    done ;
    flags.last_space <-  flags.x ;
    while
      flags.last_space >=  flags.x_start &&
      line.[flags.last_space] <> ' '
    do
      flags.last_space <- flags.last_space - 1
    done;
    if flags.x = flags.x_start && !cur_out.temp then
      Out.unskip !cur_out.out    
  end


let do_put s =
  if !verbose>3 then
    prerr_endline ("put:|"^String.escaped s^"|");
    for i = 0 to String.length s - 1 do
      do_put_char s.[i]
    done
;;


let get_last_closed () = flags.last_closed;;
let set_last_closed s = flags.last_closed<-s;;


let is_list = function
  | "UL" | "DL" | "OL" -> true
  | _ -> false
;;

let get_fontsize () = 3;;

let nostyle () =
  !cur_out.pending<-[];
  !cur_out.nostyle<-true
;;

let clearstyle () =
  !cur_out.pending<-[]
;;

let open_mod m =
  if m=(Style "CODE") then begin 
    do_put "`";
  end;
  !cur_out.active <- m::!cur_out.active
;;

let close_mod () = match !cur_out.active with
  [] -> ()
| Style "CODE"::reste ->
    do_put "'";
    !cur_out.active <- reste
| Style ""::reste ->
    !cur_out.active <- reste
| _ -> ()
;;

let erase_mods ml = ()
;;

let open_mods ml = ()
;;

let close_mods ml = ()
;;

let par = function (*Nombre de lignes a sauter avant le prochain put*)
  | Some n as p->
      begin
	flags.pending_par <-
	  (match pblock() with
	  | "QUOTE" | "QUOTATION" -> Some (n-1)
	  | _ -> Some(n-1));
	if !verbose>2 then
	  prerr_endline
	    ("par: last_close="^flags.last_closed^
	     " r="^string_of_int n);
      end
  | _ -> flags.pending_par <- None
;;

let forget_par () = 
  let r = flags.pending_par in
  flags.pending_par <- None;
  r
;;

let flush_par n =
  flags.pending_par <- None;
  let p = n+1 in
  for i=1 to p do
    do_put_char '\n'
  done;
  if !verbose >2 then
    prerr_endline
      ("flush_par : last_closed="^flags.last_closed^
       "p="^string_of_int p);
  flags.last_closed<-"rien"
;;

let try_flush_par () =
  match flags.pending_par with
  | Some n -> flush_par n
  | _ -> ()
;;

let do_pending () =
  begin match flags.pending_par with
  | Some n -> flush_par n
  | _ -> ()
  end;
  flags.last_closed <- "rien";
  (*do_open_mods*) (*ouvre les modes a l'ecriture du bloc *)
;;

(* Blocs *)

let try_open_block s args =
  (* Prepare l'environnement specifique au bloc en cours *)
  if !verbose > 2 then
    prerr_endline ("=> try_open ``"^s^"''");

  push x_stack (flags.hsize,flags.x,flags.x_start,flags.x_end,flags.first_line,flags.last_space);

  if is_list s then begin
    do_put_char '\n';
    push nitems_stack flags.nitems;
    flags.nitems <- 0;
    flags.x_start <- flags.x_start + 3;
    flags.first_line <- -2;    
    flags.hsize <- flags.x_end - flags.x_start+1;
    
    if not flags.in_align then begin
      push align_stack flags.align;
      flags.align <- Left
    end;
    if s="DL" then begin
      push dt_stack flags.dt;
      push dcount_stack flags.dcount;
      flags.dt <- "";
      flags.dcount <- "";
    end;
  end else match s with
  | "ALIGN" ->
      begin
	do_put_char '\n';
	push align_stack flags.align;
	push in_align_stack flags.in_align;
	flags.in_align<-true;
	flags.first_line <-2;
	match args with
	  "LEFT" -> flags.align <- Left
	| "CENTER" -> flags.align <- Center
	| "RIGHT" -> flags.align <- Right
	| _ -> raise (Misc.ScanError "Invalid argument in ALIGN");
      end
  |  "HEAD" ->
      begin
	do_put_char '\n';
	flags.first_line <-0 ;
	push underline_stack flags.underline;
	flags.underline <- args;
      end
  | "QUOTE" ->
      begin
	do_put_char '\n';
	push align_stack flags.align;
	push in_align_stack flags.in_align;
	flags.in_align<-true;
	flags.align <- Left;
	flags.first_line<-0;
	flags.x_start<-25 * flags.hsize / 100;
	flags.hsize <- flags.x_end - flags.x_start+1;
      end
  | "QUOTATION" ->
      begin
	do_put_char '\n';
	push align_stack flags.align;
	push in_align_stack flags.in_align;
	flags.in_align<-true;
	flags.align <- Left;
	flags.first_line<-2;
	flags.x_start<-25 * flags.hsize / 100;
	flags.hsize <- flags.x_end - flags.x_start+1;
      end
  | "PRE" ->
      flags.first_line <-0;
      do_put "\n<<";
      flags.first_line <-2;
  | "INFO" ->
      flags.first_line <-0;
  | _ -> ();

  if !verbose > 2 then
    prerr_endline ("<= try_open ``"^s^"''")
;;
    
let try_close_block s =
  let (h,x,xs,xe,fl,lp) = pop "x" x_stack in
  flags.hsize<-h; 
  flags.x_start<-xs;
  flags.x_end<-xe;
  flags.first_line <-fl;

  if (is_list s) then begin
    if not flags.in_align then begin
      let a = pop "align" align_stack in
      flags.align <- a
    end;
    flags.nitems <- pop "nitems" nitems_stack;
    if s="DL" then begin
      flags.dt <- pop "dt" dt_stack;
      flags.dcount <- pop "dcount" dcount_stack;
    end;
  end else match s with
  | "ALIGN" | "QUOTE" | "QUOTATION" ->
      begin
	let a = pop "align" align_stack in
	flags.align <- a;
	let ia = pop "in_align" in_align_stack in
	flags.in_align <- ia;
      end
  | "HEAD" ->
      begin
	let u = pop "underline" underline_stack in
	flags.underline <- u
      end
  | "PRE" ->
      flags.first_line <-0;
      do_put ">>\n"
  | _ -> ()
;;

let open_block s args =
  (* Cree et se place dans le bloc de nom s et d'arguments args *)
  if !verbose > 2 then
    prerr_endline ("=> open_block ``"^s^"''");
  let bloc,arg =
    if s="DIV" && args="ALIGN=center" then
      "ALIGN","CENTER"
    else s,args
  in
  push out_stack (bloc,arg,!cur_out);
  try_flush_par ();
  (* Sauvegarde de l'etat courant *)
  
  if !cur_out.temp || s="TEMP" then begin
    cur_out :=
      newstatus
	!cur_out.nostyle
	(!cur_out.pending @ !cur_out.active)
	[] true;
  end;
(*else begin
    if is_list s then do_put_char '\n'; (* revient a la ligne (et flushe) *)
  end;*)

  try_open_block bloc arg;
  if !verbose > 2 then
    prerr_endline ("<= open_block ``"^bloc^"''")
;;

let force_block s content =  
  if !verbose > 2 then
    prerr_endline ("   force_block ``"^s^"''");
  let old_out = !cur_out in
  let ps,pa,pout = pop "out_stack" out_stack in
  cur_out:=pout;
  if !cur_out.temp then
    Out.copy old_out.out !cur_out.out;
  try_close_block s;
  flags.last_closed<- s;
  if !cur_out.temp then
    free old_out;
;;

let close_flow s = ()
;;

let close_block s =
  (* Fermeture du bloc : recuperation de la pile *)
  if !verbose > 2 then
    prerr_endline ("=> close_block ``"^s^"''");
  let bloc =  if s = "DIV" then "ALIGN" else s in
  if is_list bloc then do_put_char '\n'; (* revient a la ligne (et flushe) *)
  if bloc= "ALIGN" || bloc="HEAD" then do_put_char '\n';
  force_block bloc "";
  if !verbose > 2 then
    prerr_endline ("<= close_block ``"^bloc^"''");
;;



let insert_block tag arg = 
  if tag = "ALIGN" then begin
    match arg with
      "LEFT" -> flags.align <- Left
    | "CENTER" -> flags.align <- Center
    | "RIGHT" -> flags.align <- Right
    | _ -> raise (Misc.ScanError "Invalid argument in ALIGN");
  end;
;;


(* Displays *)

let open_display args = ()
;;

let close_display () = ()
;;

let item_display () = ()
;;

let force_item_display () = ()
;;

let end_item_display () = 0,(fun ()->()),true
;;

let begin_item_display f is_freeze = ()
;;

let erase_display () = ()
;;

(* Autres *)

(* Listes *)
let set_dt s = flags.dt <- s

and set_dcount s = flags.dcount <- s
;;

let item scan arg =
  if !verbose > 2 then begin
    prerr_string "Item stack=";
    pretty_stack !out_stack
  end;
  if not (is_list (pblock())) then
    raise (Error "Item not inside a list element");
  
  let mods = !cur_out.pending @ !cur_out.active in
(*  do_close_mods ();*)
  let true_scan =
    if flags.nitems = 0 then begin
      let _ = forget_par() in ();
      (*let saved = Out.to_string !cur_out.out in*)
      ( fun arg -> (*do_put saved false;*) scan arg)
    end else scan in
  
  try_flush_par();
  !cur_out.pending<-mods;
  flags.nitems<-flags.nitems+1;
  match pblock() with 
    "DL" -> begin (* description list *)
      let parg = parg() in
      do_put_char '\n';
    (* Emission du champ description *)
      if flags.dcount <> "" then scan("\\refstepcounter{"^flags.dcount^"}");
      if parg<>"" then
	true_scan ("\\makelabel{"^(if arg="" then flags.dt else arg)^"}")
      else
	true_scan (if arg="" then flags.dt else arg);
      do_put_char ' '
    end
  | "OL" -> begin (* ordered list : enumerate *)
      do_put ("\n"^(string_of_int flags.nitems)^". ");
      true_scan arg
  end
  | "UL" -> begin (* unordered list : itemize *)
      do_put "\n- ";
      true_scan arg
  end
  | _->  raise (Error "Item not inside a list element")
;;

let change_block s args = ()
;;

let erase_block s = close_block s
;;

let open_group ss =  
  open_block "" "";
  open_mod (Style ss);
;;

let open_aftergroup f = ()
;;

let close_group () =
  close_mod ();
  close_block "";
;;

let put s =
  do_pending ();
  do_put s
;;

let put_char c =
  do_pending ();
  do_put_char c
;;

let flush_out () =
  Out.flush !cur_out.out
;;

let skip_line () =
  put_char '\n'
;;

let flush i = ()
;;

let delay f =
  ();;

let forget () =
()
;;


let loc_ref s1 s2 =
  put s1
;;

let loc_name s1 s2 =
  if !verbose >1 then prerr_endline "Text.loc_name";
  put s2
;;

let insert_vdisplay open_fun =[]
;;

let freeze f= ()
;;

let open_chan chan =
  free !cur_out;
  !cur_out.out<- Out.create_chan chan
;;

let close_chan () =
  Out.close !cur_out.out;
  !cur_out.out <- Out.create_buff()
;;

let to_string f =
  open_block "TEMP" "";
  f () ;
  let r = Out.to_string !cur_out.out in
  close_block "TEMP";
  r
;;

let to_style f =
  !cur_out.pending<-[];
  !cur_out.active<-[];
  f ();
  let r = !cur_out.active @ !cur_out.pending in
  r
;;

let get_current_output () =
  Out.to_string !cur_out.out
;;

let finalize check =
  if check then begin
    ();
    end;
  Out.close !cur_out.out
;;

let horizontal_line s u t =
  put_char '\n';
  let taille = (flags.hsize -1) * (int_of_string t) / 100 in
  let ligne = String.concat "" 
      [(match s with
      |	"right" -> String.make (flags.hsize - taille -1) ' '
      |	"center" -> String.make ((flags.hsize - taille)/2) ' '
      |	_ -> "");
	String.make taille '-'] in
  put ligne;
  put_char '\n';
;;


let unskip () = do_unskip ()

let put_separator () = put " "

let put_tag tag = ()
;;

let put_nbsp () =  put " "
;;

let put_open_group () =
  ()
;;

let put_close_group () =
  ()
;;

let put_in_math s =
  put s
;;
(*
let put_print_text s =
  ()
;;

let put_print_html s =
  ()
;;
*)

type align = Top | Middle | Bottom
;;

type cell = {
    mutable ver : align;
    mutable hor : align_t;
    mutable h : int;
    mutable w : int;
    mutable wrap : bool;
    mutable span : int; (* Nombre de colonnes *)
    mutable text : string
  } 
;;

type row = {
    mutable haut : int;
    mutable cells : cell Table.t;
  } 
;;

type row2 = {
    mutable hauteur : int;
    mutable cellules : cell array;
  } 

type table_flags_t = {
    mutable border : bool;
    mutable lines : int;
    mutable cols : int;
    mutable width : int;
    mutable height : int;
    mutable taille : int Table.t;
    mutable tailles : int array;
    mutable table : row2 Table.t;
    
  } 
;;

let cell = ref {
  ver = Middle;
  hor = Left;
  h = 0;
  w = 0;
  wrap = false;
  span = 1;
  text = ""
} 
;;


let row= ref {
  haut = 0;
  cells = Table.create  !cell
} 
;;

let table = ref {
  border = false;
  lines = 0;
  cols = 0;
  width = 0;
  height = 0;
  taille = Table.create 0;
  tailles = Array.create 0 0;
  table = Table.create {hauteur = 0; cellules = (Array.create 0 !cell)}
} 
;;

let table_stack = ref [];;
let row_stack = ref [];;
let cell_stack = ref [];;

let multi = ref []
and multi_stack = ref [];;

let line = ref 0
and col = ref 0
;;

let open_table border htmlargs =
  (* creation d'une table : on prepare les donnees : creation de l'environnement qvb, empilage du precedent. *)

  (* environnement de table : bordure (totale pour l'instant) ou non,
     nombre de lignes, de colonnes total
     largeur de chaque colonne (liste)
     hauteur de chaque ligne (liste)
     creation d'un out par cellule, puis on le recopie a la fin dans la liste de liste ( ou le tableau ) de string.
     chaque cellule va etre formatee. pour le centrage, il faut connaitre la taille. Donc le formatage se fera a la fin. Lors du close_table, on reparcourt toutes les cellules en les formattant => il faut garder les infos de formattage..
     
*)
  push table_stack !table;
  push row_stack !row;
  push cell_stack !cell;
  push in_table_stack flags.in_table;
  push multi_stack !multi;

  if !verbose>2 then prerr_endline "=> open_table";

  if border then !table.border<-true
  else !table.border<-false;
  Table.reset !table.table;
  !table.lines<-0;
  !table.cols<-0;
  !table.width<-0;
  !table.height<-0;
  line:=-1;
  col:=-1;
  multi := [];
  flags.in_table<-true;
;;

let new_row () =
  if !col> !table.cols then !table.cols<- !col;
  col:=-1;
  line:=!line+1;
  if !line=1 then  !table.tailles<-Table.trim !table.taille;
  Table.reset !row.cells;
  !row.haut<-0;
  if !verbose>2 then prerr_endline ("new_row, line ="^string_of_int !line)
;;


let open_cell format span =
  open_block "TEMP" "";
    
  (* preparation du formattage : les flags de position sont sauvegardes par l'ouverture du bloc TEMP *)
      

   (* remplir les champs de formattage de cell *)
  col:=!col+1;
  if !verbose>2 then prerr_endline ("open_cell, col="^string_of_int !col);
  let _=match format with 
    Tabular.Align {Tabular.vert=v ; Tabular.hor=h ; Tabular.wrap=w ; Tabular.width=size} ->
      !cell.ver <- 
	(match v with
	| "" -> Middle
	| "middle" -> Middle
	| "top" -> Top
	| "bottom" -> Bottom
	| _-> raise (Misc.Fatal ("open_cell, invalid vertical format :"^v)));
      !cell.hor <-
	(match h with
	| "" -> Left
	| "center" -> Center
	| "left" -> Left
	| "right" -> Right
	| _-> raise (Misc.Fatal ("open_cell, invalid horizontal format :"^h)));
      !cell.wrap <- w;
      if w then
	!cell.w <- 
	  (match size with
	    Some Length.Absolute l -> l
	  | Some Length.Percent l -> l * !Parse_opts.width / 100
	  | _-> !cell.wrap <- false; 0);
  | _       ->  raise (Misc.Fatal ("as_align")) in
  !cell.span <- span;
  if !cell.wrap then begin (* preparation de l'alignement *)
    !cur_out.temp <- false;
    flags.x_start <- 0;
    flags.x_end <- !cell.w;
    flags.hsize <- !cell.w;
    flags.first_line <- 0;
    flags.x <- 0;
    flags.last_space <- 0;
  end;
  open_block "" "";
;;


let close_cell content =
  if !verbose>2 then prerr_endline "=> force_cell";
  force_block "" content;
  if !cell.wrap then do_flush ();
  !cell.text<-Out.to_string !cur_out.out;
  close_block "TEMP";
  if !verbose>2 then prerr_endline ("cell :"^ !cell.text);
  (* il faut remplir les champs w et h de cell *)
  if not !cell.wrap then !cell.w <- 0;
  !cell.h <- 1;
  let taille = ref 0 in
  for i = 0 to (String.length !cell.text) -1 do
    if !cell.text.[i]='\n' then begin
      !cell.h<- !cell.h+1;
      if not !cell.wrap && (!taille > !cell.w) then begin
	!cell.w <- !taille;
	taille:=0;
      end;
    end else begin
      taille:=!taille+1;
    end;
  done;
  if (not !cell.wrap) && (!taille > !cell.w) then !cell.w <- !taille;
  if !verbose>2 then prerr_endline ("size : width="^string_of_int !cell.w^", height="^string_of_int !cell.h^", span="^string_of_int !cell.span);
  Table.emit !row.cells { ver = !cell.ver;
			  hor = !cell.hor;
			  h = !cell.h;
			  w = !cell.w;
			  wrap = !cell.wrap;
			  span = !cell.span;
			  text = !cell.text};
  (* on a la taille de la cellule, on met sa largeur au bon endroit, si necessaire.. *)
  (* Multicolonne : Il faut mettre des zeros dans le tableau pour avoir la taille minimale des colonnes atomiques. Puis on range start,end dans une liste que l'on regardera a la fin pour ajuster les tailles selon la loi : la taille de la multicolonne doit etre <= la somme des tailles minimales. Sinon, il faut agrandir les colonnes atomiques pour que ca rentre. *)
  if !cell.span = 1 then begin
    if !line=0 then
      Table.emit !table.taille !cell.w
    else
      begin
	if !col >= (Array.length !table.tailles) then 
	  begin (* depassement du tableau : on l'agrandit.. *)
	    let t = Array.create ((Array.length !table.tailles)+1) 0 in
	    Array.blit !table.tailles 0 t 0 (Array.length !table.tailles) ;
	    !table.tailles <- t
	  end;
	if (!cell.w > (!table.tailles.(!col))) then 
	  begin
	    !table.tailles.(!col)<- !cell.w;
	  end;
      end;
  end else begin
    if !line=0 then
      for i = 1 to !cell.span do
	Table.emit !table.taille 0
      done;
    multi := (!col,!col + !cell.span -1,!cell.w) :: !multi;
  end;
  col := !col + !cell.span -1;
  if !cell.h> !row.haut then !row.haut<- !cell.h;
  if !verbose>2 then prerr_endline "<= force_cell";
;;

let do_close_cell () = close_cell ""
;;

let erase_cell () =
  if !verbose>2 then prerr_endline "erase cell";
  close_block "";
  let _ = Out.to_string !cur_out.out in
  close_block "TEMP";
  col := !col -1;
;;

let erase_row () = ()

and close_row erase =
  if !verbose>2 then prerr_endline "close_row";
  Table.emit !table.table
     { hauteur = !row.haut;
     cellules = Table.trim !row.cells}; 
;;

let text_out j hauteur height align =
  match align with
  | Top ->    (j < height)
  | Middle -> ((j >= (hauteur-height)/2) && (j <= ((hauteur-height)/2)+height-1))
  | Bottom -> (j >= hauteur - height)
;;
(* dis si oui ou non on affiche la ligne de cette cellule, etant donne l'alignement vertical.*)

let put_ligne texte pos align taille =
(* envoie la ligne de texte apres pos, sur out, en alignant horizontalement et en completant pour avoir la bonne taille *)
  let pos_suiv = try 
    String.index_from texte pos '\n'
  with Not_found -> String.length texte
  in
  let s = String.sub texte pos (pos_suiv - pos) in
  let t= String.length s in
  let ligne = match align with
  | Left -> String.concat "" 
	[s; String.make (taille-t) ' ']
  | Center -> String.concat ""
	[String.make ((taille-t)/2) ' ';
	  s;
	  String.make (taille - t - (taille-t)/2) ' '] 
  | Right -> String.concat ""
	[String.make (taille-t) ' ';
	  s]
   in
  if !verbose>2 then prerr_endline ("line sent :#"^ligne^"#");
  do_put ligne;
  pos_suiv + 1
;;

let rec somme debut fin = 
  if debut = fin 
  then !table.tailles.(debut)
  else !table.tailles.(debut) + (somme (debut+1) fin)
;;


let calculate_multi () = 
  let rec do_rec = function
      [] -> ()
    | (debut,fin,taille_mini) :: reste -> begin
	let taille = somme debut fin in
	if taille < taille_mini then  (* il faut agrandir *)
	  for i = debut to fin do
	    if taille = 0
	    then
	      !table.tailles.(debut) <- taille_mini
	    else
	      !table.tailles.(i) <- !table.tailles.(i) * taille_mini / taille;
	  done; (* Attention : on agrandit aussi les colonnes p !! *)
	do_rec reste;
    end
  in
  do_rec !multi
;;

let close_table () =
  if !verbose>2 then begin
    prerr_endline "=> close_table";
    pretty_stack !out_stack
  end;
  if !line=0 then  !table.tailles<-Table.trim !table.taille;
  let tab = Table.trim !table.table in
  (* il reste a formatter et a flusher dans la sortie principale.. *)
  !table.lines<-Array.length tab;
  if !verbose>2 then prerr_endline ("lines :"^string_of_int !table.lines);

  calculate_multi ();

  !table.width<-(Array.length !table.tailles) -1;
  for i = 0 to Array.length !table.tailles -1 do
    !table.width <- !table.width + !table.tailles.(i);
  done;

  if !table.border then begin
    !table.width <- !table.width + 2;
    do_put (String.make !table.width '-');
    do_put_char '\n';
  end;
    
  for i = 0 to !table.lines - 1 do
    let ligne = tab.(i).cellules in
    (* affichage de la ligne *)
    (* il faut envoyer ligne apres ligne dans chaque cellule, en tenant compte de l'alignement vertical et horizontal..*)
    if !verbose>2 then prerr_endline ("line "^string_of_int i^", columns:"^string_of_int (Array.length ligne)^", height:"^string_of_int tab.(i).hauteur);
    let pos = Array.create (Array.length ligne) 0 in
    !row.haut <-0;
    for j = 0 to tab.(i).hauteur -1 do
      if !table.border then do_put_char '|';
      let col = ref 0 in
      for k = 0 to Array.length ligne -1 do
	begin
	  (* ligne j de la cellule k *)
	  let taille = ligne.(k).span -1+ somme !col (!col + ligne.(k).span-1) in 
	  if !verbose>3 then prerr_endline ("cell to output:"^ligne.(k).text^", taille="^string_of_int taille);
	  if text_out j tab.(i).hauteur ligne.(k).h ligne.(k).ver then begin
	    pos.(k) <- 
	      put_ligne 
		ligne.(k).text 
		pos.(k) 
		ligne.(k).hor
		taille
	  end else do_put (String.make taille ' ');
	  if !table.border then do_put_char '|'
	      else do_put_char ' ';
	  col := !col + ligne.(k).span;
	end;
      done;
      do_put_char '\n';
    done;
    if !table.border then begin
      do_put (String.make !table.width '-');
      do_put_char '\n';
    end;
  done;
  table := pop "table" table_stack;
  row := pop "row" row_stack;
  cell := pop "cell" cell_stack;
  multi := pop "multi" multi_stack;
  flags.in_table <- pop "in_table" in_table_stack;

;;


let infomenu arg = ()
;;

let infonode opt num arg = ()
;;

let is_blank s =
  let b = ref true in
  for i = 0 to String.length s do
    b := !b && s.[i]=' '
  done;
  !b
;;

let is_empty () =
  flags.in_table && (Out.is_empty !cur_out.out);;

let image arg n = 
    if arg <> "" then begin
    put arg;
    put_char ' '
  end
;;
