(*****************************************************************
 *
 *                     IMITATOR II
 * 
 * Laboratoire Specification et Verification (ENS Cachan & CNRS, France)
 * Author:        Etienne Andre
 * Created:       2012/06/18
 * Last modified: 2016/01/27
 *
 ****************************************************************)


(************************************************************)
(** Behavioral cartography auxiliary functions *)
(************************************************************)
val bc_initialize : unit -> unit

val bc_initialize_subpart : unit -> unit

val bc_process_im_result : Result.old_im_result -> bool

val bc_finalize : unit -> unit

(** Generate the graphical cartography, and possibly personnalize the file suffix *)
val output_graphical_cartography : string option -> unit

val compute_initial_pi0 : unit -> unit

(** Compute the next pi0 by sequentially trying all points until a point not covered is found; and then directly modify the internal variable 'current_pi0' (standard BC)
 * Return (found_pi0 : bool, nb_useless_points : int)
 *)
val find_next_pi0 : AbstractModel.tile_nature option -> (bool * bool)

val find_next_pi0_shuffle : AbstractModel.tile_nature option -> (bool * bool)

(** Get the current pi0 (for PaTATOR) *)
val get_current_pi0 : unit -> AbstractModel.pi0

(* Get the number of unsuccessful points (for PaTATOR) *)
val get_nb_unsuccessful_points : unit -> int


(** Get the list of *all* points in V0 (for PaTATOR) *)
(* val compute_all_pi0 : unit -> (*pi0_list*)PVal.pval list *)

val pi0_in_returned_constraint: AbstractModel.pi0 -> Result.returned_constraint -> bool

(* Move to the next uncovered pi0 and do not move if the current pi0 is still not covered; update global variable current_pi0 (if necessary); return true if indeed moved *)
val move_to_next_uncovered_pi0 : unit -> bool

(** Try to generate an uncovered random pi0, and gives up after n tries *)
val random_pi0 : int -> bool

(** Compute an array made of *all* points in V0 (for PaTATOR) *)
val compute_all_pi0 : unit -> unit

(** Shuffle the array made of *all* points in V0 (for PaTATOR) *)
val shuffle_all_pi0 : unit -> unit

val test_pi0_uncovered : AbstractModel.pi0 -> bool ref -> unit 

val find_next_pi0_cover : unit -> bool

(************************************************************)
(** Behavioral cartography algorithms *)
(************************************************************)

val random_behavioral_cartography : AbstractModel.abstract_model -> int -> (*AbstractModel.returned_constraint list*)unit

val cover_behavioral_cartography : AbstractModel.abstract_model -> (*AbstractModel.returned_constraint list*)unit


(*
 *  functions used by the coordinator in the distributed-unsupervised
 *  cartography (the coordinator maintaints a list of points instead of
 *  a single one (added by Sami Evangelista?!)
 *)
val constraint_list_init : int -> unit
val constraint_list_random : unit -> PVal.pval option
val constraint_list_update : Result.old_im_result -> unit
val constraint_list_empty : unit -> bool
