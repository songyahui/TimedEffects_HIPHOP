(*----------------------------------------------------
----------------------PRINTING------------------------
----------------------------------------------------*)

open List
open Printf
open Ast


exception Foo of string


let counter = ref 0;;

let getAnewVar = 
  counter := ! counter + 1; 
  "t" ^ string_of_int !counter;;

let counter_rewriting = ref 0;;



let getAnewVar_rewriting () = 
  counter_rewriting := ! counter_rewriting + 1; 
  "tv" ^ string_of_int !counter_rewriting;;

(*used to generate the free veriables, for subsititution*)
let freeVar = ["t1"; "t2"; "t3"; "t4";"t5";"t6";"t7";"t8";"t9";"t10"
              ;"t11"; "t12"; "t13"; "t14";"t15";"t16";"t17";"t18";"t19";"t20"
              ;"t21"; "t22"; "t23"; "t24";"t25";"t26";"t27";"t28";"t29";"t30"];;



let getAfreeVar (varList:string list):string  =
  let rec findOne li = 
    match li with 
        [] -> raise ( Foo "freeVar list too small exception!")
      | x :: xs -> if (exists (fun a -> String.compare a x == 0) varList) == true then findOne xs else x
  in
  findOne freeVar
;;




let rec iter f = function
  | [] -> ()
  | [x] ->
      f true x
  | x :: tl ->
      f false x;
      iter f tl

let to_buffer ?(line_prefix = "") ~get_name ~get_children buf x =
  let rec print_root indent x =
    bprintf buf "%s\n" (get_name x);
    let children = get_children x in
    iter (print_child indent) children
  and print_child indent is_last x =
    let line =
      if is_last then
        "└── "
      else
        "├── "
    in
    bprintf buf "%s%s" indent line;
    let extra_indent =
      if is_last then
        "    "
      else
        "│   "
    in
    print_root (indent ^ extra_indent) x
  in
  Buffer.add_string buf line_prefix;
  print_root line_prefix x

let printTree ?line_prefix ~get_name ~get_children x =
  let buf = Buffer.create 1000 in
  to_buffer ?line_prefix ~get_name ~get_children buf x;
  Buffer.contents buf

type binary_tree =
  | Node of string * (binary_tree  list )
  | Leaf

let get_name = function
    | Leaf -> "."
    | Node (name, _) -> name;;

let get_children = function
    | Leaf -> []
    | Node (_, li) -> List.filter ((<>) Leaf) li;;



let rec input_lines file =
  match try [input_line file] with End_of_file -> [] with
   [] -> []
  | [line] -> (String.trim line) :: input_lines file
  | _ -> failwith "Weird input_line return value"
;;


let string_of_state (state :signal):string = 
  match state with 
    One name -> name 
  | Zero name -> "!"^name 
  ;;


let string_of_sl (sl: instance):string = 
  List.fold_left (fun acc (sig_) -> 
  acc ^ "," ^ 
  string_of_state sig_ (*^ (
    match n with 
      None -> ";"
    | Some n -> "(" ^ string_of_int n ^");"
  )*)
  ) "" sl
;;

let string_of_instance (mapping:instance) :string = 
  let temp1 = "{" ^ string_of_sl mapping ^ "}" in 
  temp1
  ;;

let rec string_of_terms (t:terms):string = 
  match t with
    Var name -> name
  | Number n -> string_of_int n
  | Plus (t1, t2) -> (string_of_terms t1) ^ ("+") ^ (string_of_terms t2)
  | Minus (t1, t2) -> (string_of_terms t1) ^ ("-") ^ (string_of_terms t2)

  ;;

(*
let string_of_promise (pro:promise) : string = 
  match pro with 
    Sing (s, arg) -> 
    (
    match arg with 
      None -> ""
    | Some (n) -> "(" ^ string_of_int n ^")"
    )
  | Count (t, (s, arg)) ->
    "count("^string_of_terms t ^ ", "^
    (
    match arg with 
      None -> ""
    | Some (n) -> "(" ^ string_of_int n ^")"
    ) 
;;
*)




let rec string_of_es (es:es) :string = 
  match es with 
    Bot -> "_|_"  
  | Emp -> "emp"
  | Wait name -> name ^ "?"
  | Instance ins  -> string_of_instance ins
  | Cons (es1, es2) ->  "("^string_of_es es1 ^ " . " ^ string_of_es es2^")"
  | Kleene esIn -> "(" ^ string_of_es esIn ^ ")*" 
  (*| Ttimes (esIn, t) ->"(" ^ string_of_es esIn ^ ")" ^ string_of_terms t *)
  | RealTime (es, t)-> "(" ^ string_of_es es ^ "#" ^string_of_terms t^")"
  | Choice (es1, es2) -> "("^string_of_es es1 ^ " + " ^ string_of_es es2^")"
  | Par (es1, es2) -> "("^string_of_es es1 ^ " || " ^ string_of_es es2^")"
  ;;

let rec string_of_terms (t:terms):string = 
  match t with
    Var name -> name
  | Number n -> string_of_int n
  | Plus (t1, t2) -> (string_of_terms t1) ^ ("+") ^ (string_of_terms t2)
  | Minus (t1, t2) -> (string_of_terms t1) ^ ("-") ^ (string_of_terms t2)

  ;;

(*To pretty print pure formulea*)
let rec string_of_pure (p:pure):string = 
  match p with
    TRUE -> "true"
  | FALSE -> "false"
  | Gt (t1, t2) -> (string_of_terms t1) ^ ">" ^ (string_of_terms t2)
  | Lt (t1, t2) -> (string_of_terms t1) ^ "<" ^ (string_of_terms t2)
  | GtEq (t1, t2) -> (string_of_terms t1) ^ ">=" ^ (string_of_terms t2)
  | LtEq (t1, t2) -> (string_of_terms t1) ^ "<=" ^ (string_of_terms t2)
  | Eq (t1, t2) -> (string_of_terms t1) ^ "=" ^ (string_of_terms t2)
  | PureOr (p1, p2) -> "("^string_of_pure p1 ^ "\\/" ^ string_of_pure p2^")"
  | PureAnd (p1, p2) -> "("^string_of_pure p1 ^ "/\\" ^ string_of_pure p2^")"
  | Neg p -> "(!" ^ "(" ^ string_of_pure p^"))"
  ;; 


let rec string_of_effect(eff:effect): string = 
  match eff with 
    [] -> ""
  | [(p , es)] -> string_of_pure p ^ "&" ^ string_of_es es
  | (p , es)::xs -> string_of_pure p ^ "&" ^ string_of_es es  ^ "\\/" ^ string_of_effect xs 
  
;;