
open Pretty
open Ast
open List

exception Foo of string


let rec fstPar (es:Sleek.instants) :(parfst* (Sleek.term option)) list = 
  match es with 
    Bottom -> []
  | Empty -> []
  | Await s -> [(W s, None)] 
  | Instant ins ->  [(SL ins, None)]
  | Sequence (es1 , es2) ->  if Sleek__Inference.nullable es1 then append (fstPar  es1) (fstPar  es2) else fstPar  es1
  | Union (es1, es2) -> append (fstPar  es1) (fstPar  es2)
  | Timed (Instant ins, t) -> [(SL ins, Some t)]
  | Timed (Await s, t) -> [(W s, Some t)] 
  | Timed (es1, _) -> fstPar es1
  | Kleene es1 -> fstPar  es1
  | Parallel (_ , _) -> 
    (raise (Foo "should not be here fstPar"))

    (*
    let rec fstPar (pi:Sleek.pi) (es:Sleek.instants) :(Sleek.pi * parfst* (Sleek.term option)) list = 
  match es with 
    Bottom -> []
  | Empty -> []
  | Await s -> [(pi, W [s], None)] 
  | Instant ins ->  [(pi, SL ins, None)]
  | Sequence (es1 , es2) ->  if Sleek__Inference.nullable es1 then append (fstPar pi es1) (fstPar pi es2) else fstPar pi es1
  | Union (es1, es2) -> append (fstPar pi es1) (fstPar pi es2)
  | Timed (Instant ins, t) -> [(pi, SL ins, Some t)]
  | Timed (Await s, t) -> [(pi, W [s], Some t)] 
  | Timed (es1, _) -> fstPar pi es1
  | Kleene es1 -> fstPar pi es1
  | Parallel (es1 , es2) -> 
       let temp1 = fstPar pi es1 in 
    let temp2 = fstPar pi es2 in 
    let combine = zip (temp1, temp2) in 
    List.map (fun (a, b)->
      match (a, b) with 
      | ((pi1, f1, None), (pi2, f2, None)) -> 
        (
          match (f1, f2) with 
          | (W ff1, W ff2) -> (Sleek.And(pi1, pi2), W (List.append ff1 ff2), None)
          | (SL ff1, SL ff2) -> (Sleek.And(pi1, pi2), SL (Sleek__Signals.merge ff1 ff2), None)
                | _ -> raise (Foo "fstPar error")


        )
      | _ -> raise (Foo "fstPar error")
    ) combine


    
    let fst1 = fstPar es1 in
    let fst2 = fstPar es2 in
    let combine = zip (fst1,  fst2) in 
    List.map (fun (a, b) -> 
    
    List.append a b) combine
    *)
  

    ;;


let rec derivativePar (fst: parfst * (Sleek.term option)) (es:Sleek.instants) (pi:Sleek.pi): (Sleek.pi * Sleek.instants) =
  match es with 
  | Bottom ->  (pi, Bottom)
  | Empty ->  (pi, Bottom)
  | Await s -> 
    (
      match fst with 
        (W (f), None) ->  if Sleek__Signals.compare_event f s  then (pi, Empty) else (pi, Bottom)
      | (SL ins, None) -> if Sleek__Signals.isEventExist s ins then (pi, Empty) else (pi, Bottom)
      | _ -> (pi, Bottom)
    )
  | Instant ins ->  
    (
      match fst with 
      | (W f, None) ->  if Sleek__Signals.isEventExist f ins then (pi, Empty) else (pi, Bottom)
      | (SL f, None)-> if Sleek__Signals.(|-)  f ins then (pi, Empty) else (pi, Bottom)
      | _ -> (pi, Bottom)
    )

  | Timed (Instant ins, _) -> 
    (
      match fst with 
      | (W f, Some _) ->  if Sleek__Signals.isEventExist f ins then (pi, Empty) else (pi, Bottom)
      | (SL f, Some _ )-> if Sleek__Signals.(|-)  f ins then (pi, Empty) else (pi, Bottom)
      | _ -> (pi, Bottom)
    )
  | Timed (Await s, _) -> 
    (
      match fst with 
        (W (f), Some _) ->  if Sleek__Signals.compare_event f s  then (pi, Empty) else (pi, Bottom)
      | (SL ins, Some _ ) -> if Sleek__Signals.isEventExist s ins then (pi, Empty) else (pi, Bottom)
      | _ -> (pi, Bottom)
    )
    
  | Sequence (es1 , es2) -> 
      let (piF, esF) = derivativePar fst es1 pi in 
      let esL = Sleek.Sequence(esF,  es2) in  
      if Sleek__Inference.nullable es1 
      then 
          let (piR, esR) =  derivativePar fst es2 pi in 
          (Sleek.And (piF, piR), Union (esL, esR))
      else (piF, esL)

  | Union (es1, es2) -> 
      let (pi1, temp1) =  derivativePar fst es1 pi  in
      let (pi2, temp2) =  derivativePar fst es2 pi in 
      (Sleek.And (pi1, pi2), Union (temp1,temp2))

  | Timed (es1, t) -> 
    let (pi1, temp1) =  derivativePar fst es1 pi  in
    let (newTV1, newPi1) = getAnewVar_rewriting () in
    let (newTV2, newPi2) = getAnewVar_rewriting () in
    let newPi = Sleek.And(Sleek.And(newPi1, newPi2) , Sleek.And(pi1, Sleek.Atomic(Sleek.Eq, Sleek.Plus(Var newTV1, Var newTV2) , t))) in 
    (newPi, Timed(temp1, Var newTV2))

  | Kleene (es1) -> 
    let (pi1, temp1) =  derivativePar fst es1 pi  in  
    (pi1, Sleek.Sequence (temp1, es))

  | Parallel (es1, es2) -> 
      let (pi1, temp1) =  derivativePar fst es1 pi  in
      let (pi2, temp2) =  derivativePar fst es2 pi in 
      (Sleek.And (pi1, pi2), Parallel (temp1,temp2))


  ;;



(*
prog_states = 
(Sleek.pi * Sleek.instants * instance option * string option) list 

let rec lengthOfEs (es:Sleek.instants) : int =
  match es with 
    Bottom  -> raise (Foo "Bottom does not have length")
  | Empty -> 0
  | Await _ -> 1
  | Instant _ -> 1
  | Sequence (es1, es2) -> lengthOfEs es1 + lengthOfEs es2
  | Union (es1, es2) -> if lengthOfEs es1 > lengthOfEs es2 then lengthOfEs es1 else lengthOfEs es2
  | Parallel (es1, es2) -> if lengthOfEs es1 > lengthOfEs es2 then lengthOfEs es1 else lengthOfEs es2
  | Timed (es1, _) -> lengthOfEs es1 
  | Kleene es1 -> lengthOfEs es1 
  ;;
*)



let unifyOptionalTerms t1 t2 : (Sleek.term option * Sleek.pi) = 
  match (t1, t2) with 
  | (None, None) -> (None, Sleek.True )
  | (Some t, None) -> (Some t, Sleek.True )
  | (None, Some t) -> (Some t, Sleek.True )
  | (Some tt1, Some tt2) -> (Some tt1, Sleek.Atomic(Sleek.Eq, tt1, tt2) )

  ;;

let addOptionaLTerm ins t = 
  match t with 
  | None -> ins
  | Some t -> Sleek.Timed (ins, t)
  ;;
  
let rec parallelES (pi1:Sleek.pi) (pi2:Sleek.pi) (es1:Sleek.instants) (es2:Sleek.instants) : (Sleek.pi * Sleek.instants) =
  let norES1 = Sleek__Utils.fixpoint ~f: Sleek.normalize_es es1 in 
  let norES2 = Sleek__Utils.fixpoint ~f: Sleek.normalize_es es2 in 

  (*
  print_string (Sleek.show_instants (norES1)^"\n");
  print_string (Sleek.show_instants (norES2)^"\n parallelES====> \n");
*)
  match (norES1, norES2) with 
  | (_, Empty) -> (Sleek.And(pi1, pi2), norES1)
  | (Empty, _) -> (Sleek.And(pi1, pi2), norES2)
  | _ ->


  let fst1 = fstPar norES1 in
  let fst2 = fstPar norES2 in 

  let headcom = zip (fst1, fst2) in 

  let esLIST = List.map (
  fun (f1, f2) -> 
    print_string (string_of_parfst f1 ^"\n" );
    print_string (string_of_parfst f2 ^"\n" );


    let (newpi1, der1) = Sleek.normalize  (derivativePar f1 norES1 pi1) in 
    let (newpi2, der2) = Sleek.normalize  (derivativePar f2 norES2 pi2) in 
    let newPi = Sleek.And (newpi1, newpi2) in 

    match (f1, f2) with  
    | ((W s1, t1) , (W s2 , t2)) ->
      let (t_add, p_add) = unifyOptionalTerms t1 t2 in 

      (match (der1, der2) with 
      | (Empty, _) -> (Sleek.And(newPi, p_add), Sleek.Sequence (addOptionaLTerm (Parallel (Await s1, Await s2)) t_add, der2))
      | (_, Empty) -> (Sleek.And(newPi, p_add), Sleek.Sequence (addOptionaLTerm (Parallel (Await s1, Await s2)) t_add, der1))
      | (der1, der2) -> 
        let (pi, es) = (parallelES pi1 pi2 der1 der2) in 
 (*     print_string ("dsbkcjbdkj\n");
        print_string (Sleek.show_instants (der1)^"\n");
        print_string (Sleek.show_instants (der2)^"\n");
        print_string (Sleek.show_instants (es)^"\n");
*)


        (Sleek.And(pi, p_add), Sleek.Sequence (addOptionaLTerm (Parallel (Await s1, Await s2)) t_add, es))
   
      )
      

    | ((W s, t1), (SL ins, t2)) -> 
      let (t_add, p_add) = unifyOptionalTerms t1 t2 in 
      if Sleek__Signals.isEventExist s ins then 
        match (der1, der2) with 
        | (Empty, _) -> (Sleek.And(newPi, p_add), Sleek.Sequence (addOptionaLTerm (Instant ins) t_add, der2))
        | (_, Empty) -> (Sleek.And(newPi, p_add), Sleek.Sequence (addOptionaLTerm (Instant ins) t_add, der1))
        | _ -> let(p, es) = parallelES pi1 pi2 der1 der2 in 
               (Sleek.And(p, p_add), Sleek.Sequence (addOptionaLTerm (Instant ins) t_add, es))

      else 
        
        let (p, es) = parallelES pi1 pi2 es1 der2  in 
        (Sleek.And(p, p_add), Sleek.Sequence (addOptionaLTerm (Instant ins) t_add, es))

    | ((SL ins, t1), (W s ,t2)) -> 
      let (t_add, p_add) = unifyOptionalTerms t1 t2 in 

      if Sleek__Signals.isEventExist s ins then 
        match (der1, der2) with 
        | (Empty, _) -> (Sleek.And(newPi, p_add), Sleek.Sequence (addOptionaLTerm (Instant ins) t_add, der2))
        | (_, Empty) -> (Sleek.And(newPi, p_add), Sleek.Sequence (addOptionaLTerm (Instant ins) t_add, der1))
        | _ -> let(p, es) = parallelES pi1 pi2 der1 der2 in 
               (Sleek.And(p, p_add), Sleek.Sequence (addOptionaLTerm (Instant ins) t_add, es))

      else 
        let (p, es) = parallelES pi1 pi2 der1 es2  in 
        
        (Sleek.And(p, p_add), Sequence (addOptionaLTerm (Instant ins) t_add, es))

    | ((SL ins1, t1), (SL ins2, t2)) -> 
      let (t_add, p_add) = unifyOptionalTerms t1 t2 in 

      (match (der1, der2) with 
      | (Empty, _) -> 
(*
      print_string ("dsbkcjbdkj11111\n");
      print_string (Sleek.show_instants (der1)^"\n");
      print_string (Sleek.show_instants (der2)^"\n");
*)

      (Sleek.And(newPi, p_add), Sequence (addOptionaLTerm (Instant (Sleek__Signals.merge ins1 ins2)) t_add, der2))
      | (_, Empty) -> (Sleek.And(newPi, p_add), Sequence (addOptionaLTerm (Instant (Sleek__Signals.merge ins1 ins2)) t_add, der1))
      | (der1, der2) -> 
        let (pi, es) = (parallelES pi1 pi2 der1 der2) in 

        (Sleek.And(pi, p_add), Sequence (addOptionaLTerm (Instant (Sleek__Signals.merge ins1 ins2)) t_add, es))
      
    ) 
 
  ) headcom
  in 
  
  
  print_string ((List.fold_left (fun acc a -> acc ^ Sleek.show_effects [a] ) "" esLIST) ^"\n"); 


  (Sleek__Utils.fixpoint ~f: Sleek.normalize) (
  List.fold_left (fun (pacc, esacc) (p, e) -> (Sleek.And(pacc, p), Sleek.Union(esacc, e)))  (Sleek.And(pi1, pi2), Bottom) esLIST
  )

  
 ;;





(*
(Sleek.pi* Sleek.instants* (Sleek.term option * Sleek__Signals.t) option) list  
*)

let rec splitEffects (env: string list) (es:Sleek.instants) (pi:Sleek.pi) :prog_states= 
  match es with 
  | Bottom -> []
  | Empty -> [(pi, Empty, Some (None, Sleek__Signals.initUndef env))]
  | Await s -> [(pi, Await s, Some (None, Sleek__Signals.initUndef env))]
  | Instant ins -> [(pi, Empty, Some (None, Sleek__Signals.add_UndefSigs env ins))]
  | Sequence (es1, es2) -> 
    let temp = splitEffects env es2 pi in 
    List.map (fun state ->
      match state with 
      | (pi2, es2', ins2) -> (pi2, Sleek.Sequence (es1, es2'), ins2)
    ) temp
  | Union (es1, es2) -> 
    List.append (splitEffects env es1 pi ) (splitEffects env es2 pi)
  
  | Kleene es1 -> 
    let temp = splitEffects env es1 pi in 
    List.map (fun state ->
      match state with 
      | (pi2, es2', ins2) -> (pi2, Sleek.Sequence (es, es2'), ins2)
    ) temp

  | Timed (Instant ins, t) -> [(pi, Empty, Some (Some t, ins))]


  | Timed (es1, t) -> 
    let temp = splitEffects env es1 pi in 
    List.map (fun state ->
      let (newTV1, newPi1) = getAnewVar_rewriting () in
      let (newTV2, newPi2) = getAnewVar_rewriting () in
      let newPi12 = Sleek.And (newPi1, newPi2) in 
      match state with 
      | (p, e, Some (None, i)) -> 
        let newPi = Sleek.And (newPi12, Sleek.And(p, Sleek.Atomic(Sleek.Eq, Sleek.Plus(Var newTV1, Var newTV2) , t))) in 
        (newPi, Sleek.Timed (e, Sleek.Var newTV1), Some (Some (Sleek.Var newTV2), i))
      | (p, e, Some (Some t', i)) -> 
        let newPi = Sleek.And (newPi12, Sleek.And(p, Sleek.Atomic(Sleek.Eq, Sleek.Plus(Var newTV1, Var newTV2) , t))) in 
        (Sleek.And(newPi, Sleek.Atomic(Sleek.Eq, t', Var newTV2)), Sleek.Timed (e, Sleek.Var newTV1), Some (Some (Sleek.Var newTV2), i))
      | (p, e, None) ->  (p, e, None)
    ) temp

  | Parallel (es1, es2) -> 
    let (newPi, newEs) = parallelES pi pi  es1 es2 in 
    splitEffects env newEs newPi 

(*
    let len1 = lengthOfEs es1 in 
    let len2 = lengthOfEs es2 in 
    if len1 > len2 then 
      let temp = splitEffects env es1 pi in 
      List.map (fun (p, e, i) -> (p, Sleek.Parallel (e, es2), i)) temp
    else if len1 < len2 then 
      let temp = splitEffects env es2 pi in 
      List.map (fun (p, e, i) -> (p, Sleek.Parallel (e, es1), i)) temp
    else 
      let temp1 = splitEffects env es1 pi in 
      let temp2 = splitEffects env es2 pi in 
      let combine = zip (temp1, temp2) in 
      List.map (fun ((p1, e1, i1), (p2, e2, i2)) -> (Sleek.And(p1, p2), Sleek.Parallel(e1, e2), 
      (
        match (i1, i2) with 
        | (Some(None,cur1 ), Some(None,cur2 )) -> Some (None, Sleek__Signals.merge cur1 cur2)
        | _ -> None 
      )
      
      )) combine
*)

  ;;

(* (Sleek.pi * (Sleek.term option * Sleek__Signals.t) * Sleek.instants) list *)
let rec splitEffectsFromTheHead (env: string list) (es:Sleek.instants) (pi:Sleek.pi) : prog_states_reverse= 
  match es with 
  | Bottom -> []
  | Empty -> [(pi, (None, Sleek__Signals.initUndef env), Empty)]
  | Instant ins -> [(pi, (None, Sleek__Signals.add_UndefSigs env ins), Empty)]
  | Await s -> [(pi, (None, Sleek__Signals.initUndef env), Await s)]
  | Sequence (es1, es2) -> 
    let states = splitEffectsFromTheHead env es1 pi in 
    List.map (fun (pinew, h, es1') -> 
      (pinew, h, Sleek.Sequence(es1', es2))
    ) states
  | Union    (es1, es2) -> 
    let states1 = splitEffectsFromTheHead env es1 pi in 
    let states2 = splitEffectsFromTheHead env es2 pi in 
    List.append states1 states2
  | Parallel (es1, es2) ->
    let (newPi, newEs) = parallelES pi pi  es1 es2 in 
    splitEffectsFromTheHead env newEs newPi 
  | Kleene   (es1) -> 
    let states = splitEffectsFromTheHead env es1 pi in 
    List.map (fun (pinew, h, es1') -> 
      (pinew, h, Sleek.Sequence(es1', es))
    ) states
  | Timed (Instant ins, t) -> [(pi, (Some t, ins), Empty)]
  | Timed    (es1, t) -> 
    let temp = splitEffectsFromTheHead env es1 pi in 
    List.map (fun state ->
      let (newTV1, newPi1) = getAnewVar_rewriting () in
      let (newTV2, newPi2) = getAnewVar_rewriting () in
      let newPi12 = Sleek.And (newPi1, newPi2) in 
      match state with 
      | (p, (None, i), e) -> 
        let newPi = Sleek.And (newPi12, Sleek.And(p, Sleek.Atomic(Sleek.Eq, Sleek.Plus(Var newTV1, Var newTV2) , t))) in 
        (newPi, (Some (Sleek.Var newTV1), i), Sleek.Timed (e, Sleek.Var newTV2))
      | (p, (Some t', i), e) -> 
        let newPi = Sleek.And (newPi12, Sleek.And(p, Sleek.Atomic(Sleek.Eq, Sleek.Plus(Var newTV1, Var newTV2) , t))) in 
        (Sleek.And(newPi, Sleek.Atomic(Sleek.Eq, t', Var newTV1)), (Some (Sleek.Var newTV1), i), Sleek.Timed (e, Sleek.Var newTV2))
    ) temp


  ;;


let concatFromTheEnd (env:string list) (pi1:Sleek.pi) (pi2:Sleek.pi) (es1:Sleek.instants) (es2:Sleek.instants) : (Sleek.pi * Sleek.instants) list=
  let left_End = splitEffects env es1 pi1 in 
  let head_Right = splitEffectsFromTheHead env es2 pi2 in 
  let combine = zip (left_End, head_Right) in 
  List.map (fun (le, hr) ->
      match le with 
      | (p_le, es_le, None) -> (p_le, es_le)
      | (p_le, es_le, Some (None, insL))->
          (match hr with 
          | (p_hr, (None, insR), es_hr) -> 
            (Sleek.And(p_le, p_hr),  Sleek.Sequence (Sleek.Sequence(es_le , Instant(Sleek__Signals.merge insL insR)) ,  es_hr))
          | (p_hr, (Some t', insR), es_hr) -> 
            (Sleek.And(p_le, p_hr), Sleek.Sequence (Sequence(es_le , Timed ( Instant(Sleek__Signals.merge insL insR), t')) ,  es_hr))
          )
      | (p_le, es_le, Some (Some t, insL))->
          (match hr with 
          | (p_hr, (None, insR), es_hr) -> 
            (Sleek.And(p_le, p_hr), Sleek.Sequence (Sequence(es_le , Timed ( Instant(Sleek__Signals.merge insL insR), t)) ,  es_hr))
          | (p_hr, (Some t', insR), es_hr) ->  
            let pinew =  Sleek.And(Sleek.And(p_le, p_hr), Sleek.Atomic(Sleek.Eq, t, t') ) in 
            (pinew, Sleek.Sequence (Sleek.Sequence (es_le, Timed ( Instant(Sleek__Signals.merge insL insR), t)) ,  es_hr))
          )

    ) combine
    ;;


let rec findProg name full:(param list* Sleek.effects * Sleek.effects) = 
  match full with 
  | [] -> raise (Foo ("function " ^ name ^ " is not found!"))
  | x::xs -> 
    match x with 
    | ModduleDeclear (str, p_li, _, pre, post) -> 
      if String.compare str name == 0 then (p_li, pre, post)
      else findProg name xs
    | _ -> findProg name xs
;;



let tAdd_None (t:Sleek__Signals.t option  ): (Sleek.term option * Sleek__Signals.t) option=
  match t with
  | None -> None
  | Some ins -> Some (None, ins)
  ;;


let rec forward (env:string list) (current:prog_states) (prog:expression) (full: statement list): prog_states =

  match prog with 
  | Unit -> current
  | Halt -> 
      List.map (fun state ->
        match state with 
        | (pi, his, Some (_, cur)) -> (pi, Sleek.Sequence (his, Sleek.Instant cur), None)
        | (_, _, None) -> state
      )  current
  | Yield -> 
      List.map (fun state ->
        match state with 
        | (pi, his, Some (Some t, cur)) -> (pi, Sleek.Sequence (his, Sleek.Timed (Sleek.Instant cur, t)), Some (None, Sleek__Signals.initUndef env))
        | (pi, his, Some (None, cur)) -> (pi, Sleek.Sequence (his, Sleek.Instant cur), Some (None, Sleek__Signals.initUndef env))
        | (_, _, None) -> state
      )  current
    
  
  | Emit (s, _ ) -> 
      List.map (fun state ->
        match state with 
        | (pi, his, Some (t, cur)) -> (pi, his , Some (t, Sleek__Signals.merge cur (Sleek__Signals.from s)))
        | (_, _, None) -> state
      )  current

  | Signal (s, p) -> forward (s::env) current p full 

  | Seq (p1, p2) -> 
    forward env (forward env current p1 full) p2 full

  | Async (s, p) -> 
    (*print_string (string_of_prog_states current ^"\n");*)
    List.map (fun (pi1, his, cur1) ->
      match cur1 with 
      | None -> (pi1, his, cur1)
      | Some (None, cur) -> (pi1, Sleek.Sequence (his, Sleek.Instant cur), Some (None, Sleek__Signals.add_UndefSigs env (Sleek__Signals.make [(Sleek__Signals.present s)])))
      | Some (Some t, cur) -> (pi1, Sleek.Sequence (his, Sleek.Timed (Sleek.Instant cur, t)), Some (None, Sleek__Signals.add_UndefSigs env (Sleek__Signals.make [(Sleek__Signals.present s)])))
      ) (forward env current p full)

  | Run (FunctionCall (Variable mn, _)) -> 
  (*forward env current p full 

  |  ->
  *)
    let (_, precon, postcon) = findProg mn full in 

    List.flatten (

    List.fold_left (fun acc (pi, his, cur) ->

    (match cur with 
    | None -> [current]
    | Some (None, ins) -> 

      List.append acc (  
        let (verbose, _) = Sleek.verify_entailment (Sleek.Entail { lhs = [(pi, Sequence (his, Sleek.Instant ins))]; rhs = (precon) })  in 
        if verbose then 
        List.flatten (
          List.map (fun (pi1, es1) -> 
            let traces = concatFromTheEnd env pi pi1 (Sleek.Sequence(his, Sleek.Instant ins)) es1 in 
            List.map (fun (pi_new, ins_new) -> 
            let final = splitEffects env  (Sleek__Utils.fixpoint ~f: Sleek.normalize_es ins_new) pi_new  in
            final
            
            
            ) traces
            
           
          ) postcon
        )
        else raise (Foo "precondiction check failed")
      )
      
    | Some (Some t, ins) -> 

      List.append acc (  
        let (verbose, _) = Sleek.verify_entailment (Sleek.Entail { lhs = [(pi, Sequence (his, Sleek.Instant ins))]; rhs = (precon) })  in 
        if verbose then 
        List.flatten (
          List.map (fun (pi1, es1) -> 
            let traces = concatFromTheEnd env pi pi1 (Sleek.Sequence(his, Timed(Sleek.Instant ins, t))) es1 in 
            List.map (fun (pi_new, ins_new) -> splitEffects env  ins_new pi_new ) traces
           
          ) postcon
        )
        else raise (Foo "precondiction check failed")
      )
    )
   ) [] current 
    )

  

  | Await (Variable s) -> 
      List.map (fun (pi1, his, cur1) -> 
        match cur1 with 
        | None -> (pi1, his, cur1)
        | Some (None, cur) -> (pi1, Sleek.Sequence (his, Sleek.Sequence(Sleek.Instant cur, Await (Sleek__Signals.present s))), Some (None, Sleek__Signals.empty))
        | Some (Some t, cur) -> (pi1, Sleek.Sequence (his, Sleek.Sequence(Sleek.Timed (Sleek.Instant cur, t), Await (Sleek__Signals.present s))), Some (None, Sleek__Signals.empty))
      

    )  current 

  | Await (Access (s::_ )) -> 
      List.map (fun (pi1, his, cur1) -> 
        match cur1 with 
        | None -> (pi1, his, cur1)
        | Some (None, cur) -> (pi1, Sleek.Sequence (his, Sleek.Sequence(Sleek.Instant cur, Await (Sleek__Signals.present s))), Some (None, Sleek__Signals.empty))
        | Some (Some t, cur) -> (pi1, Sleek.Sequence (his, Sleek.Sequence(Sleek.Timed (Sleek.Instant cur, t), Await (Sleek__Signals.present s))), Some (None, Sleek__Signals.empty))
      

    )  current 

  | Abort (FunctionCall (_, (Variable s)::_), p) ->

  List.flatten (

    List.fold_left (fun acc (pi, his, cur) ->
      let (newTV1, newPi1) = getAnewVar_rewriting () in
      let newPi = Sleek.And (newPi1, Sleek.And(pi, Sleek.Atomic(Sleek.Lt, Var newTV1, Var s))) in 

    
      List.append acc (
        List.map (fun (pi1, his1, cur1) ->
        match cur1 with 
        | None -> [(pi1, Sleek.Sequence(his, Timed(his1, Var newTV1)), cur1)]
        | Some (None, cur) -> splitEffects env (Sleek.Sequence(his, Timed (Sleek.Sequence (his1, Sleek.Instant cur), Var newTV1))) newPi
        | Some (Some t, cur) -> splitEffects env (Sleek.Sequence(his, Timed(Sleek.Sequence (his, Sleek.Timed (Sleek.Instant cur, t)), Var newTV1))) newPi
      
        ) (forward env [(newPi, Empty, cur)] p full)

      )) [] current

  )




  | DoEvery (p, Access (str::_ ))->

    List.fold_left (fun acc (pi, his, cur) ->
  
      List.append acc (  
  
        let temp = forward env [(pi, Empty, cur)] p full in 

        List.map (fun  (pi1, his1, cur1)->
          match cur1 with 
          | None  -> (pi1, Sleek.Sequence(his, Sleek.Sequence (Await (Sleek__Signals.present str), his1)), None)
          | Some (None, ins)  -> (pi1, Sleek.Sequence(his, Sleek.Sequence (Await (Sleek__Signals.present str), his1)), Some(None, ins ))
          | Some (Some t, ins)  -> (pi1, Sleek.Sequence(his, Sleek.Sequence (Await (Sleek__Signals.present str), his1)),  Some (Some t, ins))
        ) temp
      )
    )[] current





  | ForkPar (p1::p2::[]) -> 

    let final = List.flatten (
    List.fold_left (fun acc (pi, his, cur) ->
  
    List.append acc (  
  
    let temp1 = forward env [(pi, Empty, cur)] p1 full in 
    let temp2 = forward env [(pi, Empty, cur)] p2 full in 


    print_string (string_of_states temp1^"\n---\n");
    print_string (string_of_states temp2^"\n===>\n");


    let combine = zip (temp1, temp2) in 

  
    List.map (fun (  (pi1, his1, cur1),(pi2, his2, cur2)) ->
  
   
    match (cur1, cur2) with
        
    | (Some (None, cur1), Some (None, cur2)) -> 
      
      let (pi_new, es_new) = parallelES pi1 pi2 (Sequence (his1, Instant cur1)) (Sequence (his2, Instant cur2)) in 
      List.map (fun (a, b, c) -> (a, Sleek.Sequence(his,b), c)) (splitEffects env (Sleek.normalize_es es_new) pi_new )  
    
    | (Some (Some t, cur1), Some (None, cur2))-> 
      let (pi_new, es_new) = parallelES pi1 pi2 (Sequence (his1, Timed (Instant cur1, t))) (Sequence (his2, Instant cur2)) in 
      List.map (fun (a, b, c) -> (a, Sleek.Sequence(his,b), c)) (splitEffects env (Sleek.normalize_es es_new) pi_new )  
    
    | (Some (None, cur1), Some (Some t, cur2))-> 
      let (pi_new, es_new) = parallelES pi1 pi2 (Sequence (his1, Instant cur1)) (Sequence (his2, Timed (Instant cur2, t))) in 
      List.map (fun (a, b, c) -> (a, Sleek.Sequence(his,b), c)) (splitEffects env (Sleek.normalize_es es_new) pi_new )  
    
    | (Some (Some t1, cur1), Some (Some t2, cur2))-> 
      let (pi_new, es_new) = parallelES pi1 pi2 (Sequence (his1, Timed (Instant cur1, t1))) (Sequence (his2, Timed (Instant cur2, t2))) in 
      List.map (fun (a, b, c) -> (a, Sleek.Sequence(his,b), c)) (splitEffects env (Sleek.normalize_es es_new) pi_new )  

    | _ -> 
      let (pi_new, es_new) = parallelES pi1 pi2 (Sequence(his,his1)) (his2) 
      in [(pi_new, es_new, None)] 

    ) combine
    )) [] current
    )in 

    print_string (string_of_states final^"\n");

    final


  | ForkPar (p1::p2::rest) -> 

    forward env current (ForkPar ((ForkPar ([p1; p2])) ::rest)) full


  
  | _ ->  current
 
  ;;





let forward_verification (prog : statement) (whole: statement list): string = 
  match prog with 
  | ModduleDeclear (mn, p_li , ex, pre, post) -> 

    let env = List.fold_left (fun acc a ->  List.append acc 
      (match a with 
      | OUT str -> [str]
      | _ -> []) 
      ) [] p_li in 
      
    let init = (List.fold_left (fun acc (pre_pi, pre_es) ->
        List.append acc (splitEffects env pre_es pre_pi)
        ) [] pre
      ) in 
    let raw_final = (*effects_inference*) forward env init ex whole in 
    let final = List.map (fun state ->
        match state with 
        | (pi, his, Some (None, cur)) -> Sleek.normalize (pi, Sleek.Sequence (his, Sleek.Instant cur))
        | (pi, his, Some (Some t, cur)) ->Sleek.normalize (pi, Sleek.Sequence (his, Sleek.Timed (Sleek.Instant cur, t)))

        | (pi, his, None) -> (pi, his)
      ) raw_final in 

    let (verbose, history) = Sleek.verify_entailment (Sleek.Entail { lhs = final; rhs = (post) })  in 
    "\n========== Module: "^ mn ^" ==========\n" ^
    "[Pre  Condition] " ^ show_effects_list pre ^"\n"^
    "[Post Condition] " ^ show_effects_list post ^"\n"^
    "[Final  Effects] " ^ show_effects_list (List.map (fun a -> Sleek__Utils.fixpoint ~f: Sleek.normalize a) final) ^"\n\n"^
    (*(string_of_inclusion final_effects post) ^ "\n" ^*)
    "[TRS: Verification for Post Condition]\n" ^ 
    "[" ^ (if verbose then "SUCCEED"  else "FAIL") ^ "]\n" ^ 
    Sleek.show_history  history    ~verbose ^ "\n\n"
    
  | _ -> ""
  ;;



let () =
  let inputfile = (Sys.getcwd () ^ "/" ^ Sys.argv.(1)) in
(*    let outputfile = (Sys.getcwd ()^ "/" ^ Sys.argv.(2)) in
print_string (inputfile ^ "\n" ^ outputfile^"\n");*)
  let ic = open_in inputfile in
  try
      let lines =  (input_lines ic ) in
      let line = List.fold_right (fun x acc -> acc ^ "\n" ^ x) (List.rev lines) "" in
      let progs = Parser.program Lexer.token (Lexing.from_string line) in
      
      print_string (List.fold_left (fun acc a -> acc ^ forward_verification a progs) "" progs ) ; 
      flush stdout;                (* 现在写入默认设备 *)
      close_in ic                  (* 关闭输入通道 *)

    with e ->                      (* 一些不可预见的异常发生 *)
      close_in_noerr ic;           (* 紧急关闭 *)
      raise e                      (* 以出错的形式退出: 文件已关闭,但通道没有写入东西 *)

   ;;

   (*
   statck , heap, -> op semantcis 

   traces  -> instrumental semantics. 

   state |= logic

   then the logic. 

*)