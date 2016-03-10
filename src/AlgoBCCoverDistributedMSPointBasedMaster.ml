(************************************************************
 *
 *                       IMITATOR
 * 
 * LIPN, Université Paris 13, Sorbonne Paris Cité (France)
 * 
 * Module description: Classical Behavioral Cartography with exhaustive coverage of integer points [AF10]. Distribution mode: master-slave with point-based distribution of points. [ACE14,ACN15]
 * 
 * File contributors : Étienne André
 * Created           : 2016/03/10
 * Last modified     : 2016/03/10
 *
 ************************************************************)


(************************************************************)
(************************************************************)
(* Modules *)
(************************************************************)
(************************************************************)
open OCamlUtilities
open ImitatorUtilities
open Exceptions
open AbstractModel
open Result
open AlgoGeneric
open DistributedUtilities


(************************************************************)
(************************************************************)
(* Internal exceptions *)
(************************************************************)
(************************************************************)


(************************************************************)
(************************************************************)
(* Class definition *)
(************************************************************)
(************************************************************)
class virtual algoBCCoverDistributedMSPointBasedMaster =
	object (self)
	inherit AlgoBCCoverDistributedMSPointBased.algoBCCoverDistributedMSPointBased as super
	
	(************************************************************)
	(* Class variables *)
	(************************************************************)

	(* Number of finished workers *)
	val mutable nb_finished_workers = 0
	
	(* Shortcut to avoid repeated computations *)
	val nb_workers = DistributedUtilities.get_nb_nodes() - 1
	
	
	(************************************************************)
	(* Class methods *)
	(************************************************************)

	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(* Name of the algorithm *)
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	method virtual algorithm_name : string

	
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(* Variable initialization *)
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	method initialize_variables =
(* 		super#initialize_variables; *)
		
		(* The end *)
		()


	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(** Return a new instance of the underlying cartography algorithm (typically BCrandom or BCcover) *)
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	method virtual bc_instance : AlgoCartoGeneric.algoCartoGeneric
	

(*	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(* Processing requests *)
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	method private master_process_tile abstract_im_result =
		(** Create auxiliary files with the proper file prefix, if requested *)
		(*** NOTE: cannot create files, as the real state space is on the worker machine ***)
(* 			bc#create_auxiliary_files imitator_result; *)

		(* Get the verbose mode back *)
(* 			set_verbose_mode global_verbose_mode; *)
		(*------------------------------------------------------------*)

		(* Process result *)
		bc#process_result abstract_im_result;
		
		(* Update limits *)
		bc#update_limit;
		
		(* The end *)
		()*)
	
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(* Send termination signal to a worker and keep track of the number of terminated workers *)
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	method private send_termination_signal worker_rank =
		(* Send termination signal *)
		DistributedUtilities.send_stop worker_rank;
		
		(* Update the number of finished workers *)
		nb_finished_workers <- nb_finished_workers + 1;
		
		(* Print some information *)
		self#print_algo_message Verbose_medium( "Worker " ^ (string_of_int worker_rank ) ^ " is done");
		
		(* The end *)
		()


	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(* Compute the next point and send it to the worker, or send terminate message (and update the number of terminated workers) if no more point *)
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	method private compute_and_send_point bc worker_rank =
		(* Find next point (dynamic fashion) *)
		let next_point = bc#compute_and_return_next_point in
		
		(* If point valid *)
		begin
		match next_point with
		| AlgoCartoGeneric.Some_pval pi0 ->
			(* Send to node *)
			DistributedUtilities.send_pi0 pi0 worker_rank;
		| AlgoCartoGeneric.No_more ->
			(* Send termination signal and keep track of the number of terminated workers *)
			self#send_termination_signal worker_rank;
		end;
		(* The end *)
		()


	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(* Processing requests from worker *)
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	method private process_pull_request bc =
		self#print_algo_message Verbose_high ("Entered function 'process_pull_request'...");
		
		(*** TODO ***)
(* 		counter_master_waiting#start; *)
		let pull_request = DistributedUtilities.receive_pull_request () in
		(*** TODO ***)
(* 		counter_master_waiting#stop; *)
		
		match pull_request with
		| PullOnly worker_rank ->
			self#print_algo_message Verbose_low ("Received PullOnly request...");
			
			(* Compute the next point and send it to the worker, or send terminate message if no more point *)
			self#compute_and_send_point bc worker_rank;
			
			(* The end *)
			()

		
		| OutOfBound worker_rank ->
			self#print_algo_message Verbose_low ("Received OutOfBound request...");
			(*** TODO: DO SOMETHING TO HANDLE THE CASE OF A POINT THAT WAS NOT SUCCESSFUL ***)
			raise (InternalError("OutOfBound not implemented."))

		| Tile (worker_rank , abstract_im_result) -> 
			self#print_algo_message Verbose_low ("Received Tile request...");
			self#print_algo_message_newline Verbose_standard ("[Master] Received the following constraint from worker " ^ (string_of_int worker_rank));
			
			(*** TODO: we may want to store somewhere the computation time of the worker, in order to infer its waiting/working time ***)
			
			(* Process result (before computing next point) *)
			bc#process_result abstract_im_result;
			
			(* Compute the next point and send it to the worker, or send terminate message if no more point *)
			self#compute_and_send_point bc worker_rank;
			
			(* The end *)
			()
		
		| _ -> raise (InternalError("Unsupported tag received by the master."))

	
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(* Processing last requests from worker, always send termination signal *)
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	method private process_termination_pull_request bc =
		self#print_algo_message Verbose_high ("Entered function 'process_termination_pull_request'...");
		
		(*** TODO ***)
(* 		counter_master_waiting#start; *)
		let pull_request = DistributedUtilities.receive_pull_request () in
		(*** TODO ***)
(* 		counter_master_waiting#stop; *)
		
		match pull_request with
		| PullOnly worker_rank ->
			self#print_algo_message Verbose_low ("Received PullOnly request...");
			
			(* Send termination signal and keep track of the number of terminated workers *)
			self#send_termination_signal worker_rank;
			
			(* The end *)
			()

		
		| OutOfBound worker_rank ->
			self#print_algo_message Verbose_low ("Received OutOfBound request...");
			(*** TODO: DO SOMETHING TO HANDLE THE CASE OF A POINT THAT WAS NOT SUCCESSFUL ***)
			raise (InternalError("OutOfBound not implemented."))

		| Tile (worker_rank , abstract_im_result) -> 
			self#print_algo_message Verbose_low ("Received Tile request...");
			self#print_algo_message Verbose_standard ("Received the following constraint from worker " ^ (string_of_int worker_rank));
			
			(*** TODO: we may want to store somewhere the computation time of the worker, in order to infer its waiting/working time ***)

			(* Process result *)
			bc#process_result abstract_im_result;
			
			(* Send termination signal and keep track of the number of terminated workers *)
			self#send_termination_signal worker_rank;
			
			(* The end *)
			()
		
		| _ -> raise (InternalError("Unsupported tag received by the master."))



	
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(* Algorithm for the master *)
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	method run () =
		(* Retrieve the model *)
(* 		let model = Input.get_model () in *)
		(* Retrieve the input options *)
(* 		let options = Input.get_options () in *)

		(* Create an object responsible to handle everything linked to the cartography *)
		let bc = self#bc_instance in

		(* Factoring initialization *)
		bc#initialize_cartography;
		
		(* Initialize the number of finished workers *)
		nb_finished_workers <- 0;

		self#print_algo_message Verbose_standard ("Starting...");

		
		(*** TODO : check that initial pi0 is suitable!! (could be incompatible with initial constraint) ***)

	
		(* While there is another point to explore *)
		while bc#check_iteration_condition do
			(* Wait for a pull request and process it *)
			self#process_pull_request bc;
		done; (* end while more points *)
		
		self#print_algo_message Verbose_standard ("Done with sending points; waiting for last results.");

		(*** TODO: do not wait for remaining workers when limits reached? and if fully covered?? (or rather kill them, as not sending termination will leave zombies) ***)
		
		(* Receive remaining tiles *)
		while nb_finished_workers < nb_workers do
			self#print_algo_message Verbose_medium ("" ^ ( string_of_int ( nb_workers - nb_finished_workers )) ^ " workers left" );
			self#process_termination_pull_request bc;
		done;

		self#print_algo_message Verbose_standard ("All workers done");

		(* Update termination condition *)
		bc#update_termination_condition;
	
		(* Print some information *)
		(*** NOTE: must be done after setting the limit (above) ***)
		bc#print_warnings_limit;
		
		(* Return the algorithm-dependent result *)
		bc#compute_bc_result




	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	(* Method packaging the result output by the algorithm *)
	(*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*)
	method compute_bc_result : Result.imitator_result =
		raise (InternalError("not implemented"))
(*		self#print_algo_message_newline Verbose_standard (
			"Successfully terminated " ^ (after_seconds ()) ^ "."
		);

		
		(* Get the termination status *)
		 let termination_status = match termination_status with
			| None -> raise (InternalError "Termination status not set in BCCover.compute_result")
			| Some status -> status
		in

		(* Coverage is... *)
		(*** NOTE: this is only true for the original behavioral cartography; for variants this may not hold ***)
		let coverage =
			(* INTEGER COMPLETE if termination is regular and all tiles are exact or under-approximations *)
			if termination_status = BC_Regular_termination && (List.for_all (fun abstract_im_result -> match abstract_im_result.soundness with
					| Constraint_exact | Constraint_maybe_under -> true
					| Constraint_maybe_over | Constraint_maybe_invalid -> false
				) im_results)
				then Coverage_integer_complete
			(* UNKNOWN otherwise *)
			else Coverage_unknown
		in
		
		(* Return result *)
		BC_result {
			(* Number of points in V0 *)
			size_v0				= nb_points;
			
			(* List of tiles *)
			(*** NOTE: reverse as each im_result was added as first element ***)
			tiles				= List.rev im_results;
			
			(* Total computation time of the algorithm *)
			computation_time	= time_from start_time;
			
			(* Computation time to look for points *)
			find_point_time		= find_next_point_counter#value;
			
			(* Number of points on which IM could not be called because already covered *)
			nb_unsuccessful_points = nb_unsuccessful_points;
			
			(* Evaluation of the coverage of V0 by tiles computed by the cartography *)
			coverage			= coverage;
			
			(* Termination *)
			termination			= termination_status;
		}*)


(************************************************************)
(************************************************************)
end;;
(************************************************************)
(************************************************************)
