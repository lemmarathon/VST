Require Import floyd.base.
Require Import floyd.client_lemmas.
Require Import floyd.field_mapsto.
Require Import floyd.assert_lemmas.
Require Import floyd.closed_lemmas.
Require Import floyd.canonicalize floyd.forward_lemmas floyd.call_lemmas.
Require Import floyd.nested_field_lemmas.
Require Import floyd.data_at_lemmas.
Require Import floyd.loadstore_lemmas.
Require Import floyd.array_lemmas.
Require Import floyd.unfold_data_at.
Require Import floyd.entailer.
Require Import floyd.globals_lemmas.
Require Import floyd.type_id_env.
Require Import floyd.semax_tactics.

Lemma isptr_not_Vundef:
  forall v, isptr v -> v <> Vundef.
Proof.
intros. intro; subst; inv H.
Qed.

Lemma eval_id_get:
  forall rho i v, eval_id i rho = v -> v <> Vundef -> Map.get (te_of rho) i = Some v.
Proof.
intros.
unfold eval_id in H.
destruct (Map.get (te_of rho) i).
f_equal; assumption.
subst. contradiction H0; auto.
Qed.

Ltac instantiate_Vptr :=
  match goal with
  | H:isptr (eval_id ?i ?rho), A:name ?i
    |- _ =>
        let b := fresh "b_" A in
        let z := fresh "z_" A in
        let J := fresh "H_" A in
        destruct (eval_id i rho) as [| | | | b z] eqn:J; try contradiction H;
         clear H; symmetry in J; rename J into H
  | H:isptr (eval_id ?i ?rho)
    |- _ =>
        let b := fresh "b_"  in
        let z := fresh "z_"  in
        let J := fresh "H_"  in
        destruct (eval_id i rho) as [| | | | b z] eqn:J; try contradiction H;
         clear H; symmetry in J; rename J into H
  end.

Ltac solve_nth_error :=
match goal with |- @nth_error ?T (?A::_) ?n = Some ?B => 
 first [unify n O; unfold nth_error, value; repeat f_equal; reflexivity
        | let b := fresh "n" in evar (b:nat);  unify n (S b); 
          unfold nth_error; fold (@nth_error  T); solve_nth_error
        ]
end.

Ltac rewrite_eval_id :=
 repeat match goal with H: ?v = (eval_id ?i ?rho) |- context [ (eval_id ?i ?rho) ] =>
    rewrite <- H
 end.

Ltac rel_expr :=
first [
   simple eapply rel_expr_array_load; [reflexivity | reflexivity | apply I 
   | repeat apply andp_right; [rel_expr | rel_expr | rewrite_eval_id; cancel | entailer.. ]]
 | simple apply rel_expr_tempvar;  apply eval_id_get; [solve [eauto] | congruence ]
 | simple eapply rel_expr_cast; [rel_expr | try (simpl; rewrite_eval_id; reflexivity) ]
 | simple eapply rel_expr_unop; [rel_expr | try (simpl; rewrite_eval_id; reflexivity) ]
 | simple eapply rel_expr_binop; [rel_expr | rel_expr | try (simpl; rewrite_eval_id; reflexivity) ]
 | simple apply rel_expr_const_int
 | simple apply rel_expr_const_float
 | simple apply rel_expr_const_long
 | simple eapply rel_lvalue_local
 | simple eapply rel_lvalue_global
 | simple eapply rel_lvalue_deref; [rel_expr ]
 | simple eapply rel_lvalue_field_struct; [ reflexivity | reflexivity | rel_expr ]
 | simple eapply rel_expr_lvalue; [ rel_expr | rewrite_eval_id; cancel | ]
 | match goal with |- in_range _ _ _ => hnf; omega end
 | idtac
 ].


Ltac forward_nl :=
 hoist_later_in_pre; 
 first
 [ simple eapply semax_seq';
   [simple eapply semax_loadstore_array;
       [ reflexivity | apply I | reflexivity | reflexivity| reflexivity 
       | entailer; repeat instantiate_Vptr; repeat apply andp_right;
               rel_expr
       | try solve_nth_error | auto | auto | hnf; try omega ]
    | unfold replace_nth; simpl valinject; abbreviate_semax ]
 | eapply semax_post_flipped';
   [simple eapply semax_loadstore_array;
       [ reflexivity | apply I | reflexivity | reflexivity| reflexivity 
       | entailer; repeat instantiate_Vptr; repeat apply andp_right;
               rel_expr
       | try solve_nth_error | auto | auto | hnf; try omega ]
    |  ]
 | simple eapply semax_seq';
    [eapply semax_set_forward_nl;  
      [reflexivity | entailer; repeat instantiate_Vptr; rel_expr | try apply I ]
      | let old := fresh "old" in apply exp_left; intro old;
        autorewrite with subst; try rewrite insert_local; abbreviate_semax
     ]
 | eapply semax_post_flipped';
    [eapply semax_set_forward_nl;  
      [reflexivity | entailer; repeat instantiate_Vptr; rel_expr | try apply I ]
      | let old := fresh "old" in apply exp_left; intro old;
        autorewrite with subst; try rewrite insert_local
     ]
  ].
