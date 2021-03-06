(************************************************************
 *
 *                       IMITATOR
 * 
 * Laboratoire Spécification et Vérification (ENS Cachan & CNRS, France)
 * LIPN, Université Paris 13, Sorbonne Paris Cité (France)
 * 
 * Module description: defines indexes and names for variables,actions,etc. in PTA
 * 
 * File contributors : Étienne André
 * Created           : 2010/03/10
 * Last modified     : 2015/10/22
 *
 ************************************************************)


 
(****************************************************************)
(** Indexes *)
(****************************************************************)

type action_index = int
type action_name = string

type automaton_index = int
type automaton_name = string

type location_index = int
type location_name = string

type variable_index = int
type clock_index = variable_index
type parameter_index = variable_index
type discrete_index = variable_index
type variable_name = string


