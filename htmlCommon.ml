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

let header = "$Id: htmlCommon.ml,v 1.38 2002-06-04 11:37:06 maranget Exp $" 

(* Output function for a strange html model :
     - Text elements can occur anywhere and are given as in latex
     - A new grouping construct is given (open_group () ; close_group ())
*)

open Misc
open Element
open Parse_opts
open Latexmacros
open Stack
open Length



type block =
  | H1 | H2 | H3 | H4 | H5 | H6
  | PRE
  | TABLE | TR | TD
  | DISPLAY
  | QUOTE | BLOCKQUOTE
  | DIV
  | UL | OL | DL
  | GROUP | AFTER | DELAY | FORGET
  | INTERN
  | P
  | NADA
  | OTHER of string
;;

let string_of_block = function
  | H1 -> "H1"
  | H2 -> "H2"
  | H3  -> "H3"
  | H4 -> "H4"
  | H5 -> "H5"
  | H6 -> "H6"
  | PRE -> "PRE"
  | TABLE -> "TABLE"
  | TR -> "TR"
  | TD  -> "TD"
  | DISPLAY -> "DISPLAY"
  | QUOTE -> "QUOTE"
  | BLOCKQUOTE -> "BLOCKQUOTE"
  | DIV -> "DIV"
  | UL -> "UL"
  | OL -> "OL"
  | DL -> "DL"
  | GROUP -> ""
  | AFTER -> "AFTER"
  | DELAY -> "DELAY"
  | FORGET -> "FORGET"
  | P     -> "P"
  | NADA  -> "NADA"
  | INTERN -> "INTERN"
  | OTHER s -> s

let block_t = Hashtbl.create 17
;;

let no_opt = false
;;


let add b =
  Hashtbl.add block_t (string_of_block b) b

and add_verb s b = Hashtbl.add block_t s b
  ;;

add H1 ;
add H2 ;
add H3 ;
add H4 ;
add H5 ;
add H6 ;
add PRE ;
add TABLE ;
add TR ;
add TD ;
add DISPLAY ;
add QUOTE ;
add BLOCKQUOTE ;
add DIV ;
add UL ;
add OL ;
add DL ;
begin
  if no_opt then
    Hashtbl.add block_t "" INTERN
  else
    add GROUP
end ;
add AFTER ;
add DELAY ;
add FORGET ;
add P ;
add NADA ; ()
;;


let failclose s b1 b2=
  raise (Misc.Close (s^": ``"^string_of_block b1^"'' closes ``"^
                     string_of_block b2^"''"))
;;

let find_block s =
  let s = String.uppercase s in
  try Hashtbl.find block_t s with
  | Not_found -> OTHER s
;;

let check_block_closed opentag closetag =
  if opentag <> closetag && not (opentag = AFTER && closetag = GROUP) then
    failclose "html" closetag opentag
;;

(* output globals *)
type t_env = {here : bool ; env : text}

type t_top = 
    {top_pending : text list ; top_active : t_env list ;} 

type style_info =
  | Nothing of t_top
  | Activate of t_top
  | Closed of t_top * int 
  | ActivateClosed of t_top
  | NotMe
  | Insert of bool * text list

let get_top_lists = function
  | Nothing x -> x | Activate x -> x
  | _ -> raise Not_found

let do_pretty_mods stderr f mods =
  let rec do_rec stderr = function
    [x]  -> f stderr x
  | x::xs ->
     Printf.fprintf stderr "%a; %a" f x do_rec xs
  | [] -> () in
  Printf.fprintf stderr "[%a]" do_rec mods


let tbool = function
  | true -> "+"
  | false -> "-"

let pretty_mods stderr = do_pretty_mods stderr
    (fun stderr text -> Printf.fprintf stderr "%s" (pretty_text text))

and pretty_tmods stderr = 
  do_pretty_mods stderr
    (fun stderr {here=here ; env = env} ->
      Printf.fprintf stderr "%s%s" (tbool here) (pretty_text env))
     
let pretty_top_styles stderr {top_pending = pending ; top_active = active} =
  Printf.fprintf stderr
    "{top_pending=%a, top_active=%a}"
    pretty_mods pending
    pretty_tmods active


let pretty_top stderr = function
  | Nothing x -> Printf.fprintf stderr "Nothing %a"  pretty_top_styles x
  | Activate x -> Printf.fprintf stderr "Activate %a" pretty_top_styles x
  | Closed _ -> Printf.fprintf stderr "Closed"
  | ActivateClosed _ -> Printf.fprintf stderr "ActivateClosed"
  | NotMe -> Printf.fprintf stderr "NotMe"
  | Insert (b,active) ->
      Printf.fprintf stderr "Insert %b %a" b pretty_mods active

type status = {
  mutable nostyle : bool ;
  mutable pending : text list ;
  mutable active : t_env list ;
  mutable top : style_info ;
  mutable out : Out.t}
;;

let as_env  {env=env} =  env
let as_envs tenvs r  =
    List.fold_right (fun x r -> as_env x::r) tenvs r

let to_pending pending active = pending @ as_envs active []

let with_new_out out =  {out with out = Out.create_buff ()}

let free out = Out.free out.out
  
let cur_out =
  ref {nostyle=false ;
        pending = [] ; active = [] ;
        top = NotMe ;
        out = Out.create_null ()}
;;

type stack_item =
  Normal of block * string * status
| Freeze of (unit -> unit)
;;

exception PopFreeze
;;

let push_out s (a,b,c) = push s (Normal (a,b,c))
;;

let pretty_stack s = Stack.pretty 
   (function Normal (s,args,_) -> "["^string_of_block s^"]-{"^args^"} "
   | Freeze _   -> "Freeze ") s
;;

let rec pop_out s = match pop s with
| Normal (a,b,c) -> a,b,c
| Freeze f       -> raise PopFreeze
(* begin
  if !verbose > 2 then begin
     prerr_string "unfreeze in pop_out" ;
     pretty_stack !s
  end ;
  f () ; pop_out s end
*)
;;


let out_stack =
  Stack.create_init "out_stack" (Normal (NADA,"",!cur_out))
;;

type saved_out = status * stack_item Stack.saved

let save_out () = !cur_out, Stack.save out_stack
and restore_out (a,b) =
  if !cur_out != a then begin
    free !cur_out ;
    Stack.finalize out_stack
      (function
        | Normal (_,_,x) -> x == a
        | _ -> false)
      (function
        | Normal (_,_,out) -> free out
        | _ -> ())
  end ;  
  cur_out := a ;
  Stack.restore out_stack b

let pblock () =
  if Stack.empty out_stack then NADA
  else
    match Stack.top out_stack with
    | Normal (s,_,_) -> s
    | _ -> NADA
;;

let do_put_char c =
 if !verbose > 3 then
    prerr_endline ("put_char: |"^String.escaped (String.make 1 c)^"|");
  Out.put_char !cur_out.out c

and do_put s =
 if !verbose > 3 then
    prerr_endline ("put: |"^String.escaped s^"|");
  Out.put !cur_out.out s
;;


(* Flags section *)
(* Style information for caller *)

type flags_t = {
    mutable table_inside:bool;
    mutable in_math : bool;
    mutable ncols:int;
    mutable empty:bool;
    mutable blank:bool;
    mutable pending_par: int option;
    mutable vsize:int;
    mutable nrows:int;
    mutable table_vsize:int;
    mutable nitems:int;
    mutable dt:string;
    mutable dcount:string;
    mutable last_closed:block;
    mutable in_pre:bool;
    mutable insert: (block * string) option;
    mutable insert_attr: (block * string) option;
} ;;

let pretty_cur {pending = pending ; active = active ;
               top = top} =
  Printf.fprintf stderr "pending=%a, active=%a\n"
    pretty_mods pending
    pretty_tmods active ;
  Printf.fprintf stderr "top = %a" pretty_top top ;
  prerr_endline "" 
  
;;

let activate_top out = match out.top with
| Nothing x -> out.top <- Activate x
|  _      -> ()

and close_top n out = match  out.top with
| Nothing top  -> out.top <- Closed (top, n+Out.get_pos out.out)
| Activate top -> out.top <- ActivateClosed top
|  _       -> ()

let debug_attr stderr = function
  | None -> Printf.fprintf stderr "None"
  | Some (tag,attr) ->
      Printf.fprintf stderr "``%s'' ``%s''"
        (string_of_block tag) attr

let debug_flags f =
  Printf.fprintf stderr "attr=%a\n" debug_attr f.insert_attr ;
  flush stderr

    
let flags = {
  table_inside = false;
  ncols = 0;
  in_math = false;
  empty = true;
  blank = true;
  pending_par = None;
  vsize = 0;
  nrows = 0;
  table_vsize = 0;
  nitems = 0;
  dt = "";
  dcount = "";
  last_closed = NADA;
  in_pre = false;
  insert = None;
  insert_attr = None;
} ;;

let copy_flags {
  table_inside = table_inside;
  ncols = ncols;
  in_math = in_math;
  empty = empty;
  blank = blank;
  pending_par = pending_par;
  vsize = vsize;
  nrows = nrows;
  table_vsize = table_vsize;
  nitems = nitems;
  dt = dt;
  dcount = dcount;
  last_closed = last_closed;
  in_pre = in_pre;
  insert = insert;
  insert_attr = insert_attr;
} = {
  table_inside = table_inside;
  ncols = ncols;
  in_math = in_math;
  empty = empty;
  blank = blank;
  pending_par = pending_par;
  vsize = vsize;
  nrows = nrows;
  table_vsize = table_vsize;
  nitems = nitems;
  dt = dt;
  dcount = dcount;
  last_closed = last_closed;
  in_pre = in_pre;
  insert = insert;
  insert_attr = insert_attr;
}
and set_flags f {
  table_inside = table_inside ;
  ncols = ncols;
  in_math = in_math;
  empty = empty;
  blank = blank;
  pending_par = pending_par;
  vsize = vsize;
  nrows = nrows;
  table_vsize = table_vsize;
  nitems = nitems;
  dt = dt;
  dcount = dcount;
  last_closed = last_closed;
  in_pre = in_pre;
  insert = insert;
  insert_attr = insert_attr;
} =
  f.table_inside <- table_inside;
  f.ncols <- ncols;
  f.in_math <- in_math;
  f.empty <- empty;
  f.blank <- blank;
  f.pending_par <- pending_par;
  f.vsize <- vsize;
  f.nrows <- nrows;
  f.table_vsize <- table_vsize;
  f.nitems <- nitems;
  f.dt <- dt;
  f.dcount <- dcount;
  f.last_closed <- last_closed;
  f.in_pre <- in_pre;
  f.insert <- insert ;
  f.insert_attr <- insert_attr ;
;;


    
(* Independant stacks for flags *)
type stack_t = {
  s_table_inside : bool Stack.t ;
  s_saved_inside : bool Stack.t ;
  s_in_math : bool Stack.t ;
  s_ncols : int Stack.t ;
  s_empty : bool Stack.t ;
  s_blank : bool Stack.t ;
  s_pending_par : int option Stack.t ;
  s_vsize : int Stack.t ;
  s_nrows : int Stack.t ;
  s_table_vsize : int Stack.t ;
  s_nitems : int Stack.t ;
  s_dt : string Stack.t ;
  s_dcount : string Stack.t ;
  s_insert : (block * string) option Stack.t ;
  s_insert_attr : (block * string) option Stack.t ;
(* Other stacks, not corresponding to flags *)
  s_active : Out.t Stack.t ;
  s_after : (string -> string) Stack.t
  } 

let stacks = {
  s_table_inside = Stack.create "inside" ;
  s_saved_inside = Stack.create "saved_inside" ;
  s_in_math = Stack.create_init "in_math" false ;
  s_ncols = Stack.create "ncols" ;
  s_empty = Stack.create_init "empty" false;
  s_blank = Stack.create_init "blank" false ;
  s_pending_par = Stack.create "pending_par" ;
  s_vsize = Stack.create "vsize" ;
  s_nrows = Stack.create_init "nrows" 0 ;
  s_table_vsize = Stack.create_init "table_vsize" 0 ;
  s_nitems = Stack.create_init "nitems" 0 ;
  s_dt = Stack.create_init "dt" "" ;
  s_dcount = Stack.create_init "dcount" "" ;
  s_insert = Stack.create_init "insert" None;
  s_insert_attr = Stack.create_init "insert_attr" None;
  s_active = Stack.create "active" ;
  s_after = Stack.create "after"
} 

type saved_stacks = {
  ss_table_inside : bool Stack.saved ;
  ss_saved_inside : bool Stack.saved ;
  ss_in_math : bool Stack.saved ;
  ss_ncols : int Stack.saved ;
  ss_empty : bool Stack.saved ;
  ss_blank : bool Stack.saved ;
  ss_pending_par : int option Stack.saved ;
  ss_vsize : int Stack.saved ;
  ss_nrows : int Stack.saved ;
  ss_table_vsize : int Stack.saved ;
  ss_nitems : int Stack.saved ;
  ss_dt : string Stack.saved ;
  ss_dcount : string Stack.saved ;
  ss_insert : (block * string) option Stack.saved ;
  ss_insert_attr : (block * string) option Stack.saved ;
(* Other stacks, not corresponding to flags *)
  ss_active : Out.t Stack.saved ;
  ss_after : (string -> string) Stack.saved
  } 

let save_stacks () =
{
  ss_table_inside = Stack.save stacks.s_table_inside ;
  ss_saved_inside = Stack.save stacks.s_saved_inside ;
  ss_in_math = Stack.save stacks.s_in_math ;
  ss_ncols = Stack.save stacks.s_ncols ;
  ss_empty = Stack.save stacks.s_empty ;
  ss_blank = Stack.save stacks.s_blank ;
  ss_pending_par = Stack.save stacks.s_pending_par ;
  ss_vsize = Stack.save stacks.s_vsize ;
  ss_nrows = Stack.save stacks.s_nrows ;
  ss_table_vsize = Stack.save stacks.s_table_vsize ;
  ss_nitems = Stack.save stacks.s_nitems ;
  ss_dt = Stack.save stacks.s_dt ;
  ss_dcount = Stack.save stacks.s_dcount ;
  ss_insert = Stack.save stacks.s_insert ;
  ss_insert_attr = Stack.save stacks.s_insert_attr ;
  ss_active = Stack.save stacks.s_active ;
  ss_after = Stack.save stacks.s_after
}   

and restore_stacks
{
  ss_table_inside = saved_table_inside ;
  ss_saved_inside = saved_saved_inside ;
  ss_in_math = saved_in_math ;
  ss_ncols = saved_ncols ;
  ss_empty = saved_empty ;
  ss_blank = saved_blank ;
  ss_pending_par = saved_pending_par ;
  ss_vsize = saved_vsize ;
  ss_nrows = saved_nrows ;
  ss_table_vsize = saved_table_vsize ;
  ss_nitems = saved_nitems ;
  ss_dt = saved_dt ;
  ss_dcount = saved_dcount ;
  ss_insert = saved_insert ;
  ss_insert_attr = saved_insert_attr ;
  ss_active = saved_active ;
  ss_after = saved_after
}   =
  Stack.restore stacks.s_table_inside saved_table_inside ;
  Stack.restore stacks.s_saved_inside saved_saved_inside ;
  Stack.restore stacks.s_in_math saved_in_math ;
  Stack.restore stacks.s_ncols saved_ncols ;
  Stack.restore stacks.s_empty saved_empty ;
  Stack.restore stacks.s_blank saved_blank ;
  Stack.restore stacks.s_pending_par saved_pending_par ;
  Stack.restore stacks.s_vsize saved_vsize ;
  Stack.restore stacks.s_nrows saved_nrows ;
  Stack.restore stacks.s_table_vsize saved_table_vsize ;
  Stack.restore stacks.s_nitems saved_nitems ;
  Stack.restore stacks.s_dt saved_dt ;
  Stack.restore stacks.s_dcount saved_dcount ;
  Stack.restore stacks.s_insert saved_insert ;
  Stack.restore stacks.s_insert_attr saved_insert_attr ;
  Stack.restore stacks.s_active saved_active ;
  Stack.restore stacks.s_after saved_after


let check_stack what =
  if not (Stack.empty what)  && not !silent then begin
    prerr_endline
      ("Warning: stack "^Stack.name what^" is non-empty in Html.finalize") ;
  end
;;

let check_stacks () = match stacks with
{
  s_table_inside = s_table_inside ;
  s_saved_inside = s_saved_inside ;
  s_in_math = s_in_math ;
  s_ncols = s_ncols ;
  s_empty = s_empty ;
  s_blank = s_blank ;
  s_pending_par = s_pending_par ;
  s_vsize = s_vsize ;
  s_nrows = s_nrows ;
  s_table_vsize = s_table_vsize ;
  s_nitems = s_nitems ;
  s_dt = s_dt ;
  s_dcount = s_dcount ;
  s_insert = s_insert ;
  s_insert_attr = s_insert_attr ;
  s_active = s_active ;
  s_after = s_after
}  ->  
  check_stack s_table_inside ;
  check_stack s_saved_inside ;
  check_stack s_in_math ;
  check_stack s_ncols ;
  check_stack s_empty ;
  check_stack s_blank ;
  check_stack s_pending_par ;
  check_stack s_vsize ;
  check_stack s_nrows ;
  check_stack s_table_vsize ;
  check_stack s_nitems ;
  check_stack s_dt ;
  check_stack s_dcount ;
  check_stack s_insert ;
  check_stack s_insert_attr ;
  check_stack s_active ;  
  check_stack s_after

(*
  Full state saving
*)

type saved = flags_t * saved_stacks * saved_out

let check () =
  let saved_flags = copy_flags flags
  and saved_stacks = save_stacks ()
  and saved_out = save_out () in
  saved_flags, saved_stacks, saved_out

  
and hot (f,s,o) =
  set_flags flags f ;
  restore_stacks s ;
  restore_out o
  

let sbool = function true -> "true" | _ -> "false"
;;

let prerr_flags s =
  prerr_endline ("<"^string_of_int (Stack.length stacks.s_empty)^"> "^s^
    " empty="^sbool flags.empty^
    " blank="^sbool flags.blank^
    " table="^sbool flags.table_inside)

let is_header = function
  | H1 | H2 | H3 | H4 | H5 | H6 -> true
  | _ -> false
;;

let is_list = function
  UL | DL | OL -> true
| _ -> false
;;

let string_of_par = function
  | Some i -> "+"^string_of_int i
  | None   -> "-"

let par_val last now n =
  let r = 
    if is_list last then begin
      if is_list now then 1 else 0
    end
    else if last = P then
      0
    else if
      is_header last || last = PRE || last = BLOCKQUOTE
    then n-1
    else if last = DIV || last = TABLE then n
    else n+1 in
  if !verbose > 2 then
    Printf.fprintf stderr
      "par_val last=%s, now=%s, r=%d\n"
      (string_of_block last) 
      (string_of_block now) r ;
  r
;;

let par  = function
  | Some n as p ->
      flags.pending_par <- p ;
      if !verbose > 2 then
        prerr_endline
          ("par: last_close="^ string_of_block flags.last_closed^
           " r="^string_of_int n)
  | _ -> ()
;;

let flush_par n =
  flags.pending_par <- None ;
  for i = 1 to n do
    do_put "<BR>\n"
  done ;
  if n <= 0 then do_put_char '\n' ;
  if !verbose > 2 then
     prerr_endline
       ("flush_par: last_closed="^ string_of_block flags.last_closed^
       " p="^string_of_int n);
  flags.vsize <- flags.vsize + n;
  flags.last_closed <- NADA
;;

type t_try = Wait of block | Now
let string_of_wait = function
  | Wait b -> "(Wait "^string_of_block b^")"
  | Now    -> "Now"

let try_flush_par block = match block with
| Wait GROUP -> ()
| _ ->  match flags.pending_par with
  | Some n ->
      flush_par
        (match block with
        | Wait b -> par_val b NADA n
        | _ -> par_val NADA NADA n)
  | _      -> ()


let string_of_into = function
  | Some n -> "+"^string_of_int n
  | None -> "-"

let forget_par () =
  let r = flags.pending_par in
  if !verbose > 2 then
    prerr_endline
      ("forget_par: last_close="^ string_of_block flags.last_closed^
       " r="^string_of_into r) ;  
  flags.pending_par <- None ;
  r
;;



(* styles *)

  
let do_close_mod = function
| Style m ->
    if flags.in_math && !Parse_opts.mathml then 
      if m="mtext" then do_put ("</"^m^">")
      else do_put "</mstyle>"
    else do_put ("</"^m^">")
| StyleAttr (t,_) -> 
    if flags.in_math && !Parse_opts.mathml then 
      ()
    else
      do_put ("</"^t^">")
| (Color _ | Font _)  -> 
    if flags.in_math && !Parse_opts.mathml then 
      do_put "</mstyle>"
    else do_put "</FONT>"

and do_open_mod e =
  if !verbose > 3 then
      prerr_endline ("do_open_mod: "^pretty_text e) ;
  match e with
  | Style m ->  
    if flags.in_math && !Parse_opts.mathml then 
      if m="mtext" then do_put ("<"^m^">")
      else do_put ("<mstyle style = \""^
		   (match m with
		     "B" -> "font-weight: bold "
		   | "I" -> "font-style: italic "
		   | "TT" -> "font-family: courier "
		   | "EM" -> "font-style: italic "
		   | _ -> m)^
		   "\">")
    else do_put ("<"^m^">")
  | StyleAttr (t,a) ->
      if flags.in_math && !Parse_opts.mathml then ()
      else
        do_put ("<"^t^" "^a^">")
| Font i  ->
    if flags.in_math && !Parse_opts.mathml then 
      do_put ("<mstyle style = \"font-size: "^string_of_int i^"\">")
    else do_put ("<FONT SIZE="^string_of_int i^">")
| Color s ->
    if flags.in_math && !Parse_opts.mathml then 
      do_put ("<mstyle style = \"color: "^s^"\">")
    else do_put ("<FONT COLOR="^s^">")
;;


let do_close_tmod = function
  | {here = true ; env = env} -> do_close_mod env
  | _ -> ()

let close_active_mods active = List.iter do_close_tmod active

let do_close_mods () =
  close_active_mods !cur_out.active ;
  !cur_out.active <- [] ;
  !cur_out.pending <- []
;;


let do_close_mods_pred pred same_constr =
  let tpred {env=env} = pred env in

  let rec split_again = function
    | [] -> [],None,[]
    | {here = false ; env=env} :: rest
      when same_constr env && not (pred env) ->
        [],Some env,rest
    | m :: rest ->
        let to_close,to_open,to_keep = split_again rest in
        match to_open with
        | Some _ -> m::to_close,to_open,to_keep
        | None   -> to_close,to_open,m::to_keep in
        
  let rec split = function
    | [] -> [],None,[]
    | m :: rest ->
        let to_close,close,to_keep = split rest in
        match close with
        | None ->
            if tpred m then
              if m.here then [],Some m.env,to_keep
              else
                [],None,to_keep
            else [], None, m::to_keep
        | Some _ ->
            m::to_close,close,to_keep in

  let rec filter_pred = function
    | [] -> []
    | x :: rest ->
        if pred x then filter_pred rest
        else x::filter_pred rest in
          
  let to_close,close,to_keep = split !cur_out.active in

  
  filter_pred
    (match close with
    | None -> []
    | Some env ->      
        List.iter do_close_tmod to_close ;
        do_close_mod env ;
        let (to_close_open,to_open,to_keep) = split_again to_keep in
        begin match to_open with
        | None ->
            !cur_out.active <- to_keep ;
            as_envs to_close []
        | Some env ->
            !cur_out.active <- to_keep ;
            List.iter do_close_tmod to_close_open ;
            as_envs to_close
              (as_envs to_close_open [env])
        end),
  close

        
let close_mods () = do_close_mods ()
;;


let is_style = function
  |  Style _|StyleAttr (_,_) -> true
  | _ -> false

and is_font = function
  Font _ -> true
| _ -> false

and is_color = function
  Color _ -> true
| _ -> false

;;

let do_open_these_mods do_open_mod pending =
  let rec do_rec color size = function
    |   [] -> []
    | Color _ as e :: rest  ->
        if color then
          let rest = do_rec true size rest in
          {here=false ; env=e}::rest
        else begin
          let rest = do_rec true size rest in
          do_open_mod e ;
          {here=true ; env=e}::rest
        end
    | Font _ as e :: rest ->
        if size then
          let rest = do_rec color true rest in
          {here=false ; env=e}::rest
        else
          let rest = do_rec color true rest in
          do_open_mod e ;
          {here=true ; env=e}::rest
    | e :: rest ->
        let rest = do_rec color size rest in
        do_open_mod e ;
        {here=true ; env=e} :: rest in
  do_rec
    false
    false
    pending

let activate caller pending =
  let r = do_open_these_mods (fun _ -> ()) pending in
  if !verbose > 2 then begin
    prerr_string ("activate: ("^caller^")") ;
    pretty_mods stderr pending ; prerr_string " -> " ;
    pretty_tmods stderr r ;
    prerr_endline ""
  end ;
  r

let get_top_active = function
  | Nothing {top_active = active} -> active
  | Activate {top_pending = pending ; top_active = active} ->
      activate "get_top_active" pending @ active
  | _ -> []

let all_to_pending out =
  try
    let top = get_top_lists out.top in
    to_pending out.pending out.active @
    to_pending top.top_pending top.top_active
  with
  | Not_found ->
    to_pending out.pending out.active

let all_to_active out = activate "all_to_active" (all_to_pending out)

(* Clear styles *)
let clearstyle () =
  close_active_mods !cur_out.active ;
  close_active_mods (get_top_active !cur_out.top) ;
  close_top 0 !cur_out ;
  !cur_out.pending <- [] ;
  !cur_out.active <- []
;;

(* Avoid styles *)
let nostyle () =
  clearstyle () ;
  !cur_out.nostyle <- true
;;

(* Create new statuses, with appropriate pending lists *)

let create_status_from_top out = match out.top with
| NotMe|Closed _|ActivateClosed _|Insert (_,_) ->
   {nostyle=out.nostyle ; pending = []  ; active = []  ;
   top =
     Nothing
       {top_pending = out.pending ; top_active = out.active} ;
   out = Out.create_buff ()}
| Nothing {top_pending = top_pending ; top_active=top_active} ->
    assert (out.active=[]) ;
    {nostyle=out.nostyle ; pending = [] ; active = [] ;
    top =
      Nothing
        {top_pending = out.pending @ top_pending ;
        top_active = top_active} ;
    out = Out.create_buff ()}
| Activate {top_pending = top_pending ; top_active=top_active} ->
    {nostyle=out.nostyle ; pending = [] ; active = [] ;
    top=
      Nothing
        {top_pending = out.pending ;
        top_active = out.active @ activate "top" top_pending @ top_active} ;
    out=Out.create_buff ()}

    
let create_status_from_scratch nostyle pending =
   {nostyle=nostyle ;
   pending =pending  ; active = []  ;
   top=NotMe ;
   out = Out.create_buff ()}

let do_open_mods () =
  if !verbose > 2 then begin
    prerr_string "=> do_open_mods: " ;
    pretty_cur !cur_out
  end ;

  let now_active =
    do_open_these_mods do_open_mod !cur_out.pending in
  activate_top !cur_out ;
  !cur_out.active <- now_active @ !cur_out.active ;
  !cur_out.pending <- [] ;
  
  if !verbose > 2 then begin
    prerr_string "<= do_open_mods: " ;
    pretty_cur !cur_out
  end



  
let do_pending () =  
  begin match flags.pending_par with
  | Some n ->
      flush_par (par_val flags.last_closed (pblock()) n)
  | _ -> ()
  end ;
  flags.last_closed <- NADA ;
  do_open_mods ()
;;


let one_cur_size pending active =
  let rec cur_size_active = function
    | [] -> raise Not_found
    | {here=true ; env=Font i}::_ -> i
    | _::rest -> cur_size_active rest in

  let rec cur_size_pending = function
    | [] -> cur_size_active active
    | Font i::_ -> i
    | _::rest -> cur_size_pending rest in
  cur_size_pending pending
;;

let cur_size out =
  try one_cur_size out.pending out.active
  with Not_found ->    
    try
      let top_out = get_top_lists out.top in
      one_cur_size top_out.top_pending top_out.top_active
    with Not_found -> 3

let one_first_same x same_constr pending active =
  let rec same_active = function
    | {here=true ; env=y} :: rest ->
        if same_constr y then x=y
        else same_active rest
    | _::rest -> same_active rest
    | [] -> raise Not_found in
  let rec same_pending = function
    | [] -> same_active active
    | y::rest ->
        if same_constr y then x=y
        else same_pending rest in
  same_pending pending
;;

let first_same x same_constr out =
  try
    one_first_same x same_constr out.pending out.active
  with Not_found ->
    try
      let top_out = get_top_lists out.top in
      one_first_same x same_constr top_out.top_pending top_out.top_active
    with
    | Not_found -> false

let already_here = function
| Font i ->
   i = cur_size !cur_out
| x ->
  first_same x
   (match x with
     Style _|StyleAttr (_,_) ->  is_style
   | Font _ -> is_font
   | Color _ -> is_color)
   !cur_out
;;

let ok_pre x = match x with
| Color _ | Font _ | Style "SUB" | Style "SUP" ->  not !Parse_opts.pedantic
| _ -> true
;;

let rec filter_pre = function
  [] -> []
| e::rest ->
   if ok_pre e then e::filter_pre rest
   else filter_pre rest
;;

let ok_mod e =
  (not flags.in_pre || ok_pre e) &&
  (not (already_here e))
;;

let get_fontsize () = cur_size !cur_out


let rec erase_rec pred = function
  [] -> None
| s::rest ->
   if pred s then
     Some rest
   else
     match erase_rec pred rest with
     | Some rest -> Some (s::rest)
     | None -> None
;;


let erase_mod_pred pred same_constr =
  if not !cur_out.nostyle then begin
    match erase_rec pred !cur_out.pending with
    | Some pending ->
        !cur_out.pending <- pending
    | None ->
        let re_open,closed = do_close_mods_pred pred same_constr in
        match closed with
        | Some _ ->
            !cur_out.pending <- !cur_out.pending @ re_open
        | None ->
            activate_top !cur_out ;
            try
              let tops = get_top_lists !cur_out.top in
              !cur_out.active <- 
                 !cur_out.active @
                 activate "erase" tops.top_pending @
                 tops.top_active ;
              close_top 0 !cur_out ;
              let re_open,_ = do_close_mods_pred pred same_constr in
              !cur_out.pending <- !cur_out.pending @ re_open
            with
            | Not_found -> ()
  end
;;

let same_env = function
  | Style s1 -> (function | Style s2 -> s1 = s2 | _ -> false)
  | StyleAttr (t1,a1) ->
      (function | StyleAttr (t2,a2)-> t1 = t2 && a1=a2 | _ -> false)
  | Font i1 ->
      (function | Font i2 -> i1 = i2 | _ -> false)
  | Color s1 ->
      (function | Color s2 -> s1 = s2 | _ -> false)

and same_constr = function
  | Color _ -> is_color
  | Font _ -> is_font
  | Style _|StyleAttr (_,_) -> is_style

let erase_mods ms =
  let rec erase_rec = function
    | [] -> ()
    | m :: ms ->
        erase_mod_pred (same_env m) (same_constr m) ;
        erase_rec ms in
  erase_rec ms
;;

let open_mod  m =
  if not !cur_out.nostyle then begin
    if !verbose > 3 then begin
      prerr_endline ("open_mod: "^pretty_text m^" ok="^sbool (ok_mod m)) ;
      pretty_cur !cur_out
    end ;
    begin match m with
    | Style "EM" ->
        if already_here m then
          erase_mods [m]
        else
          !cur_out.pending <- m :: !cur_out.pending
    | _ ->
        if ok_mod m then begin
          !cur_out.pending <- m :: !cur_out.pending
        end
    end
  end
;;

let rec open_mods = function
  m::rest -> open_mods rest ; open_mod m
| []      -> ()
;;



(* Blocks *)

let pstart = function
  |  H1 | H2 | H3 | H4 | H5 | H6
  | PRE 
  | DIV 
  | BLOCKQUOTE
  | UL | OL | DL
  | TABLE -> true
  | _ -> false
;;

let is_group = function
  | GROUP -> true
  | _ -> false

and is_pre = function
  | PRE -> true
  | _ -> false

let rec do_try_open_block s =  
  if !verbose > 2 then
    prerr_flags ("=> try open ``"^string_of_block s^"''");  
  if s=DISPLAY then begin
    do_try_open_block TABLE ;
    do_try_open_block TR  ;
  end else begin
    push stacks.s_empty flags.empty ; push stacks.s_blank flags.blank ;
    push stacks.s_insert flags.insert ;
    flags.empty <- true ; flags.blank <- true ;
    flags.insert <- None ;
    begin match s with
    | PRE -> flags.in_pre <- true (* No stack, cannot nest *)
    | TABLE ->
      push stacks.s_table_vsize flags.table_vsize ;
      push stacks.s_vsize flags.vsize ;
      push stacks.s_nrows flags.nrows ;
      flags.table_vsize <- 0 ;
      flags.vsize <- 0 ;
      flags.nrows <- 0
    |  TR ->
      flags.vsize <- 1
    |  TD ->
      push stacks.s_vsize flags.vsize ;
      flags.vsize <- 1
    | _ ->
        if is_list s then begin
          push stacks.s_nitems flags.nitems;
          flags.nitems <- 0 ;
          if s = DL then begin
            push stacks.s_dt flags.dt ;
            push stacks.s_dcount flags.dcount;
            flags.dt <- "";
            flags.dcount <- ""
          end
        end
    end
  end ;
  if !verbose > 2 then
    prerr_flags ("<= try open ``"^string_of_block s^"''")
      ;;

let try_open_block s args =
  push stacks.s_insert_attr flags.insert_attr ;
  begin match flags.insert_attr with
  | Some (TR,_) when s <> TR -> ()
  | _ -> flags.insert_attr <- None
  end ;
  do_try_open_block s

let do_do_open_block s args =
  if s = TR || is_header s then
    do_put "\n";
  do_put_char '<' ;
  do_put (string_of_block s) ;
  if args <> "" then begin
    if args.[0] <> ' ' then do_put_char ' ' ;
    do_put args
  end ;
  do_put_char '>'

  
let rec do_open_block insert s args = match s with
| GROUP|DELAY|FORGET|AFTER|INTERN ->
   begin match insert with
   | Some (tag,iargs) -> do_do_open_block tag iargs
   | _ -> ()
   end
| DISPLAY ->
   do_open_block insert TABLE "" ;
   do_open_block None TR args
| _  -> begin match insert with
  | Some (tag,iargs) ->
      if is_list s || s = TABLE then begin
        do_do_open_block tag iargs ;
        do_do_open_block s args
      end else begin
        do_do_open_block s args ;
        do_do_open_block tag iargs
      end
  | _ -> do_do_open_block s args
end

let rec do_try_close_block s =
  if !verbose > 2 then
    prerr_flags ("=> try close ``"^string_of_block s^"''") ;
  if s = DISPLAY then begin
    do_try_close_block TR ;
    do_try_close_block TABLE
  end else begin
    let ehere = flags.empty and ethere = pop  stacks.s_empty in
    flags.empty <- (ehere && ethere) ;
    let bhere = flags.blank and bthere = pop  stacks.s_blank in
    flags.blank <- (bhere && bthere) ;
    flags.insert <- pop  stacks.s_insert ;
    begin match s with 
    | PRE   -> flags.in_pre <- false (* PRE cannot nest *)
    | TABLE ->
      let p_vsize = pop stacks.s_vsize in
      flags.vsize <- max
       (flags.table_vsize + (flags.nrows)/3) p_vsize ;
      flags.nrows <- pop  stacks.s_nrows ;
      flags.table_vsize <- pop stacks.s_table_vsize
    |  TR ->
        if ehere then begin
          flags.vsize <- 0
        end ;
        flags.table_vsize <- flags.table_vsize + flags.vsize;
        if not ehere then flags.nrows <- flags.nrows + 1
    | TD ->
        let p_vsize = pop stacks.s_vsize in
        flags.vsize <- max p_vsize flags.vsize
    | _ ->
        if is_list s then begin
          flags.nitems <- pop stacks.s_nitems ;
          if s = DL then begin
            flags.dt <- pop stacks.s_dt ;
            flags.dcount <- pop  stacks.s_dcount
          end
        end
    end
  end ;
  if !verbose > 2 then
    prerr_flags ("<= try close ``"^string_of_block s^"''")

let try_close_block s =
  begin match flags.insert_attr with
  | Some (tag,_) when tag = s ->
      flags.insert_attr <- pop stacks.s_insert_attr
  | _ -> match pop stacks.s_insert_attr with
    | None -> ()
    | Some (_,_) as x -> flags.insert_attr <- x
  end ;
  do_try_close_block s

let do_do_close_block s =
  do_put "</" ;
  do_put (string_of_block s) ;
  do_put_char '>' ;
  match s with TD -> do_put_char '\n' | _ -> ()

let rec do_close_block insert s = match s with
|  GROUP|DELAY|FORGET|AFTER|INTERN -> 
   begin match insert with
   | Some (tag,_) -> do_do_close_block tag
   | _ -> ()
   end
| DISPLAY ->
    do_close_block None TR ;
    do_close_block insert TABLE
| s  -> begin match insert with
  | Some (tag,_) ->
      if is_list s || s = TABLE then begin
        do_do_close_block s;
        do_do_close_block tag
      end else begin
        do_do_close_block tag;
        do_do_close_block s
      end
  | _ -> do_do_close_block s
end    

let check_empty () = flags.empty

and make_empty () =
  flags.empty <- true ; flags.blank <- true ;
  !cur_out.top <- NotMe ;
  !cur_out.pending <-  to_pending !cur_out.pending !cur_out.active ;
  !cur_out.active <- []  
;;

let rec open_top_styles = function
  | NotMe|Insert (_,_) -> (* Real block, inserted block *)
        begin match !cur_out.top with
        | Nothing tops ->
            let mods =
              to_pending !cur_out.pending !cur_out.active @
              to_pending tops.top_pending tops.top_active in
            assert (!cur_out.active=[]) ;
            close_active_mods tops.top_active ;
           !cur_out.top <- Closed (tops,Out.get_pos !cur_out.out);
            Some mods
        | Activate tops ->
            !cur_out.top <- ActivateClosed tops ;
            let mods =
              to_pending !cur_out.pending !cur_out.active @
              to_pending tops.top_pending tops.top_active in
            close_active_mods !cur_out.active ;
            close_active_mods (activate "open_top_styles" tops.top_pending) ;
            close_active_mods tops.top_active ;
            Some mods
        | _ ->
            let mods = to_pending !cur_out.pending !cur_out.active in
            close_active_mods !cur_out.active ;
            Some mods
        end
  | Closed (_,n) -> (* Group that closed top_styles (all of them) *)
      let out = !cur_out in
      let mods = all_to_pending out in
      close_top n out ;
      Some mods
  | Nothing _ -> (* Group with nothing to do *)
      None
  | Activate _ -> (* Just activate styles *)
      do_open_mods () ;
      None
  | ActivateClosed tops ->
      do_open_mods () ;
      let r = open_top_styles (Closed (tops,Out.get_pos !cur_out.out)) in
      r


let rec force_block s content =
  if !verbose > 2 then begin
    prerr_endline ("=> force_block: ["^string_of_block s^"]");    
    pretty_cur !cur_out
  end ;
  let was_empty = flags.empty in
  if s = FORGET then begin
    make_empty () ;
  end else if flags.empty then begin
    flags.empty <- false; flags.blank <- false ;
    do_open_mods () ;
    do_put content
  end ;
  if s = TABLE || s=DISPLAY then flags.table_inside <- true;
(*  if s = PRE then flags.in_pre <- false ; *)
  let true_s = if s = FORGET then pblock() else s in
  let insert = flags.insert
  and insert_attr = flags.insert_attr
  and was_nostyle = !cur_out.nostyle
  and was_top = !cur_out.top in

  do_close_mods () ;
  try_close_block true_s ;
  do_close_block insert true_s ;
  let ps,args,pout = pop_out out_stack in  
  check_block_closed ps true_s ;
  let old_out = !cur_out in  
  cur_out := pout ;
  if s = FORGET then free old_out
  else if ps <> DELAY then begin
    let mods = open_top_styles was_top in
    
    do_open_block insert s
      (match insert_attr with
      | Some (this_tag,attr) when this_tag = s -> args^" "^attr
      | _ -> args) ;

    begin match was_top with
    | Insert (_,mods) ->
        ignore (do_open_these_mods do_open_mod mods)
    | _ -> ()
    end ;
(*
    prerr_endline "****** NOW *******" ;
    pretty_cur !cur_out ;
    prerr_endline "\n**********" ;
*)
    if ps = AFTER then begin
      let f = pop stacks.s_after in
      Out.copy_fun f old_out.out !cur_out.out
    end else begin
      Out.copy old_out.out !cur_out.out
    end ;
    free old_out ;    
    begin match mods with
    | Some mods ->
        !cur_out.active  <- [] ;
        !cur_out.pending <- mods
    | _ -> ()
    end
  end else begin (* ps = DELAY *)
    raise (Misc.Fatal ("html: unflushed DELAY"))
  end ;
  if not was_empty && true_s <> GROUP && true_s <> AFTER then
    flags.last_closed <- true_s ;

  if !verbose > 2 then begin
    prerr_endline ("<= force_block: ["^string_of_block s^"]");    
    pretty_cur !cur_out
  end ;

    
and close_block_loc pred s =
  if !verbose > 2 then
    prerr_string ("close_block_loc: ``"^string_of_block s^"'' = ");
  if not (pred ()) then begin
    if !verbose > 2 then prerr_endline "do it" ;
    force_block s "";
    true
  end else begin
    if !verbose > 2 then prerr_endline "forget it" ;
    force_block FORGET "";
    false
  end

and open_block s args =
 if !verbose > 2 then begin
   prerr_endline ("=> open_block ``"^string_of_block s^"''");
   pretty_cur !cur_out ;
 end ;
 try_flush_par (Wait s);

 push_out out_stack (s,args,!cur_out) ;
 cur_out :=
    begin if is_group s then
      create_status_from_top !cur_out
    else
      create_status_from_scratch
        !cur_out.nostyle
        (let cur_mods = all_to_pending !cur_out in
        if flags.in_pre || is_pre s then filter_pre cur_mods else cur_mods)
    end ;
 try_open_block s args ;
 if !verbose > 2 then begin
   prerr_endline ("<= open_block ``"^string_of_block s^"''");
   pretty_cur !cur_out ;
 end ;
;;

  
let insert_block tag arg =
  begin match !cur_out.top with
  | Nothing {top_pending=pending ; top_active=active} ->
      !cur_out.pending <- !cur_out.pending @ to_pending pending active ;
      assert (!cur_out.active = []) ;
      !cur_out.top <- Insert (false,[])
  | Activate {top_pending=pending ; top_active=active} ->
      let add_active = activate "insert_block" pending @ active in
      !cur_out.active <- !cur_out.active @ add_active ;
      !cur_out.top <- Insert (true,to_pending [] add_active)
  | Closed (_,n) ->
      Out.erase_start n !cur_out.out ;
      !cur_out.top <- Insert (false,[])
  | ActivateClosed {top_active=active ; top_pending=pending}->
      !cur_out.top <- Insert (false,to_pending pending active)
  | NotMe -> ()
  | Insert _ -> ()
  end ;
  flags.insert <- Some (tag,arg)

let insert_attr tag attr =
  match tag,flags.insert_attr with
  | TD, Some (TR,_) -> ()
  | _, _ -> flags.insert_attr <- Some (tag,attr)

let close_block  s =
  let _ = close_block_loc check_empty s in
  ()
;;

let erase_block s =
  if !verbose > 2 then begin
    Printf.fprintf stderr "erase_block: %s" (string_of_block s);
    prerr_newline ()
  end ;
  try_close_block s ;
  let ts,_,tout = pop_out out_stack in
  if ts <> s && not (s = GROUP && ts = INTERN) then
    failclose "erase_block" s ts;
  free !cur_out ;
  cur_out := tout
;;
   

let open_group ss =
  let e = Style ss in
  if no_opt || (ss  <> "" && (not flags.in_pre || (ok_pre e))) then begin
    open_block INTERN "" ;
    if ss <> "" then
      !cur_out.pending <- !cur_out.pending @ [e]
  end else
    open_block GROUP ""
    
and open_aftergroup f =
  open_block AFTER "" ;
  flags.empty <- false ;
  push stacks.s_after f

and close_group () =
  match pblock () with
  | INTERN -> close_block INTERN
  | AFTER  -> force_block AFTER ""
  | _      -> close_block GROUP
;;



(* output requests  *)
let is_blank = function
   ' ' | '\n' -> true
| _ -> false
;;

let put s =
  let block = pblock () in
  match block with
  | TABLE|TR -> ()
  | _ -> 
      let s_blank =
        let r = ref true in
        for i = 0 to String.length s - 1 do
          r := !r && is_blank (String.unsafe_get s i)
        done ;
        !r in
      let save_last_closed = flags.last_closed in
      do_pending () ;
      flags.empty <- false;
      flags.blank <- s_blank && flags.blank ;
      do_put s ;
      if s_blank then flags.last_closed <- save_last_closed
;;

let put_char c =
  let s = pblock () in
  match s with
  | TABLE|TR -> ()
  | _ -> 
      let save_last_closed = flags.last_closed in
      let c_blank = is_blank c in
      do_pending () ;
      flags.empty <- false;
      flags.blank <- c_blank && flags.blank ;
      do_put_char c ;
      if c_blank then flags.last_closed <- save_last_closed
;;


let flush_out () = 
  Out.flush !cur_out.out
;;

let skip_line () =
  flags.vsize <- flags.vsize + 1 ;
  put "<BR>\n"
;;

let put_length which  = function
  | Pixel x -> put (which^string_of_int x)
  | Char x -> put (which^string_of_int (Length.font * x))
  | Percent x  -> put (which^"\""^string_of_int x^"%\"")
  | Default    -> ()
  | No s       -> raise (Misc.Fatal ("No-length ``"^s^"'' in outManager"))

let horizontal_line attr width height =
  open_block GROUP "" ;
  nostyle () ;
  put "<HR" ;
  begin match attr with "" -> () | _ -> put_char ' ' ; put attr end ;
  put_length " WIDTH=" width ;
  put_length " SIZE=" height ;
  put_char '>' ;
  close_block GROUP
;;

let line_in_table h =
  let pad = (h-1)/2 in
  put "<TABLE BORDER=0 WIDTH=\"100%\" CELLSPACING=0 CELLPADDING=" ;
  put (string_of_int pad) ;
  put "><TR><TD></TD></TR></TABLE>"

let freeze f =
  push out_stack (Freeze f) ;
  if !verbose > 2 then begin
    prerr_string "freeze: stack=" ;
    pretty_stack out_stack
  end
;;

let flush_freeze () = match top out_stack with
  Freeze f ->
    let _ = pop out_stack in
    if !verbose > 2 then begin
      prerr_string "flush_freeze" ;
      pretty_stack out_stack
    end ;
    f () ; true
| _ -> false
;;

let pop_freeze () = match top  out_stack with
  Freeze f -> 
    let _ = pop out_stack in
    f,true
| _ -> (fun () -> ()),false
;;


let try_open_display () =
  push stacks.s_ncols flags.ncols ;
  push stacks.s_table_inside flags.table_inside ;
  push stacks.s_saved_inside false ;
  flags.table_inside <- false ;
  flags.ncols <- 0

and try_close_display () =
  flags.ncols <- pop stacks.s_ncols ;
  flags.table_inside <- pop stacks.s_saved_inside || flags.table_inside ;
  flags.table_inside <- pop stacks.s_table_inside || flags.table_inside
;;


let close_flow_loc s =
  if !verbose > 2 then
    prerr_endline ("close_flow_loc: "^string_of_block s) ;

  let active  = !cur_out.active
  and pending = !cur_out.pending in
  if close_block_loc check_empty s then begin
    !cur_out.pending <- to_pending pending active ;
    true
  end else begin
    !cur_out.pending <- to_pending pending active ;
    false
  end


let close_flow s =
  assert (s <> GROUP) ;
  if !verbose > 2 then
    prerr_flags ("=> close_flow ``"^string_of_block s^"''");
  let _ = close_flow_loc s in
  if !verbose > 2 then
    prerr_flags ("<= close_flow ``"^string_of_block s^"''")



let get_block s args =
  if !verbose > 2 then begin
    prerr_flags "=> get_block";
  end ;
  do_close_mods () ;
  let pempty = top stacks.s_empty
  and pblank = top stacks.s_blank
  and pinsert = top stacks.s_insert in
  try_close_block (pblock ()) ;
  flags.empty <- pempty ; flags.blank <- pblank ; flags.insert <- pinsert;
  do_close_block None s ;
  let _,_,pout = pop_out out_stack in  
  let old_out = !cur_out in  
  cur_out := with_new_out pout ;
  let mods = as_envs !cur_out.active !cur_out.pending in
  do_close_mods () ;
  do_open_block None s args ;
  Out.copy old_out.out !cur_out.out ;
  free old_out ;    
  !cur_out.pending <- mods ;
  let r = !cur_out in
  cur_out := pout ;
  if !verbose > 2 then begin
    Out.debug stderr r.out ;
    prerr_endline "";
    prerr_flags "<= get_block"
  end ;
  r

let hidden_to_string f =
(*
  prerr_string "to_string: " ;
  Out.debug stderr !cur_out.out ;
  prerr_endline "" ;
*)
  let old_flags = copy_flags flags in
  let _ = forget_par () in
  open_block INTERN "" ;
  f () ;
  do_close_mods () ;
  let flags_now = copy_flags flags in
  let r = Out.to_string !cur_out.out in
  flags.empty <- true ;
  close_block INTERN ;
  set_flags flags old_flags ;
  r,flags_now
;;

let to_string f =
  let r,_ = hidden_to_string f in
  r
