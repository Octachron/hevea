{
open Misc
open Lexstate
open Lexing


let subst_buff = Out.create_buff ()
;;
} 

rule subst = parse
| '#' ['1'-'9']
    {let lxm = lexeme lexbuf in
    if is_plain '#' then begin
      let i = Char.code (lxm.[1]) - Char.code '1' in
      scan_arg (fun arg -> subst (Lexing.from_string arg)) i
    end else
      Out.put subst_buff lxm ;
    subst lexbuf}
| '#' '#'+ ['1'-'9']?
    {let lxm = lexeme lexbuf in    
    if is_plain '#' then
      Out.put subst_buff (String.sub lxm 1 (String.length lxm-1))
    else
      Out.put subst_buff lxm ;
    subst lexbuf}
|  "\\#" | '\\' | [^'\\' '#']+
    {Out.put subst_buff (lexeme lexbuf) ; subst lexbuf}
|  eof {()}
| "" {raise (Error "Empty lexeme in subst")}

{

let do_subst_this (arg,env) =
  if not (top_level ()) then begin
    try
      let _ = String.index arg '#' in
      if !verbose > 1 then begin
        Printf.fprintf stderr "subst_this : [%s]\n" arg ;
        prerr_args ()
      end ;
      let _ = scan_this_arg subst (arg,env) in
      let r = Out.to_string subst_buff in
      if !verbose > 1 then
        prerr_endline ("subst_this ["^arg^"] = "^r);
      r
    with Not_found -> arg
  end else
    arg
;;

let subst_this lexbuf = do_subst_this (lexbuf,get_subst ())

let subst_arg lexbuf = do_subst_this (save_arg lexbuf)  
and subst_opt def lexbuf = do_subst_this (save_opt def lexbuf)  
and subst_csname lexbuf = Save.csname lexbuf subst_this
} 
