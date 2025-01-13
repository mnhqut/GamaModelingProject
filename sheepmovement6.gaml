/**
* Name: sheepmovement6
* Based on the internal empty template. 
* Author: minh
* Tags: 
*/


model sheepmovement6

//Pause the experiement when adding obstacles to prevent bugs
global {
	float step <- 1#s;

	
	// other parameters
	bool display_free_space <- false;
	bool display_force <- false;
	bool display_target <- false;
	bool display_circle_min_dist <- true;
	float P_shoulder_length <- 0.45;
	float P_proba_detour <- 0.5;
	bool P_avoid_other <- true;
	float P_obstacle_consideration_distance <- 3.0;
	float P_pedestrian_consideration_distance <- 3.0;
	float P_tolerance_target <- 0.1;
	bool P_use_geometry_target <- true;
	
	// sfm model parameters
	string P_model_type <- "advanced" ;	
	
	
	float P_A_pedestrian_SFM_advanced <- 4.5;
	float P_A_obstacles_SFM_advanced <- 4.5 ;
	float P_B_pedestrian_SFM_advanced <- 5 ;
	float P_B_obstacles_SFM_advanced <- 5 ;
	float P_relaxion_SFM_advanced  <- 0.5 ;
	
	float P_gama_SFM_advanced <- 0.5 ;
	float P_lambda_SFM_advanced <- 0.5 ;
	
	float P_minimal_distance_advanced <- 1.5#m;	
	
	////////////////////

	int nb_sheep <- 50;
	float P_pred_distance <- 20#m;
	float P_herd_distance <- 10#m;
	float P_food_distance <- 7#m;
	float P_cell_distance <- 8#m;
	int P_min_nearby <- 5; 
	int P_max_nearby <- 10;
	float P_trampledPathThreshold <- 0.7;
	
	float P_food_spawn_rate <- 0.5 max: 1.0 min:0.1;
	float P_rate_get_trample <- 0.003;
	float P_rate_trample_decay <- 0.0005;
	
	float P_modify_target_val <- 10#m;
	/////////////////////////////////

	geometry shape <- square(200 #m);
	
	int nb_food <- 0 update: length(parcel where each.hasFood = true);
	
	action clicka {  // action to control one dog
		ask dog_a {
			target <- #user_location;
		}
	}
	
	action clicks {   // action to control the other dog
		ask dog_s {
			target <- #user_location;
		}
	}
	
	action make_obstacle {   //action to make obstacle
		create obstacle with: [cell: parcel closest_to #user_location ] ;
	}
	
	action delete_obstacle {   //action to delete obstacle
		ask obstacle where (each.cell overlaps #user_location){
			self.cell.hasObstacle <- false;
			do die;
		}
	}
	
	action make_path {          //action to make path by making trample cell
		ask parcel closest_to #user_location {
			do make_trample;
		}
	}
	
	action delete_path {          //action to delete path by deleting trample cell
		ask parcel closest_to #user_location {
			do delete_trample;
		}
	}
	
	init {
		create dog_a with: (location: {0#m, 200#m});
		create dog_s with: (location: {200#m, 0#m});

		// create and initialize sheeps
		create sheep number:nb_sheep{
			location <- {rnd(90,110)#m, rnd(90,110)#m};
			obstacle_consideration_distance <-P_obstacle_consideration_distance;
			pedestrian_consideration_distance <-P_pedestrian_consideration_distance;
			shoulder_length <- P_shoulder_length;
			avoid_other <- P_avoid_other;
			proba_detour <- P_proba_detour;
			
			use_geometry_waypoint <- P_use_geometry_target;
			tolerance_waypoint<- P_tolerance_target;
			pedestrian_species <- [sheep];
			obstacle_species<-[obstacle];
			
			pedestrian_model <- P_model_type;
			
			A_pedestrians_SFM <- P_A_pedestrian_SFM_advanced;
			A_obstacles_SFM <- P_A_obstacles_SFM_advanced;
			B_pedestrians_SFM <- P_B_pedestrian_SFM_advanced;
			B_obstacles_SFM <- P_B_obstacles_SFM_advanced;
			relaxion_SFM <- P_relaxion_SFM_advanced;
			gama_SFM <- P_gama_SFM_advanced;
			lambda_SFM <- P_lambda_SFM_advanced;
			minimal_distance <- P_minimal_distance_advanced;
			
			
		}	
	}
	
	reflex stop when: empty(sheep) {
		do pause;
	}
	
}

grid parcel height:100 width: 100 {
	float trampledness <- 0.95 max: 0.95 min:0.5; // the smaller the value, the more trampled a plot is
	float food_spawn_rate <- P_food_spawn_rate;
	bool hasFood <- false;
	float probSpawn <- 0.0;
	bool hasObstacle <- false;

	init {
		color <- rgb(202.0, 132, 60);  // light brown
	}

	reflex spawn_food when: hasObstacle = false {
		if (hasFood = false){
			// the more food exist, the lower the spawn rate
			probSpawn <- food_spawn_rate/1000 * (1-nb_food/100000);
			if flip(probSpawn) = true{
				hasFood <- true;
			}
		}
		
		else{
			// if many sheep step on it (grazing), the food run out
			if trampledness < 0.8{
				hasFood <- false;
			}
		}
	}
	
	// cell get trampled when sheeps step on it
	reflex get_trample {
		list<sheep> sheepsInGrid <- sheep where (each overlaps self);
		// the cell get trample by sheep
		loop s over: sheepsInGrid {
			trampledness <- trampledness - s.speed*P_rate_get_trample;
		}
		 // the trampledness being decayed
		if trampledness < 0.94{
			trampledness <- trampledness +  P_rate_trample_decay;
		}
		
		// change color from light brown to deep brown based on trampledness
		color <- rgb(trampledness * 202.0, trampledness * 132.0, trampledness * 60.0);

	
	}
	
	// allow user to create and delete trample path
	action make_trample {
		trampledness <- 0.5;
	}
	
	action delete_trample{
		trampledness <- 0.95;
	}
		
	aspect default {
				draw square(2#m) color: color border: #black ;
				if hasFood {
					draw circle(0.5#m) color: #green;
				}
	}			
}

species obstacle {
	parcel cell ;
	init {
		location <- cell.location;
		cell.hasFood <- false;
		cell.hasObstacle <- true;
	}
	
	aspect default {
		draw square(2#m) color: #grey border: #black ;
	}
}


species dog skills:[moving]{
	point target;
	float speed <- 30 #km/#h;
	init {
		shape <- circle(1#m);
	}
	
	reflex move when: target != nil {
		do goto target: target ;
		if (location = target){
			target <- nil;
		}
	}
	
	aspect default {
		draw shape at: location ;
	}
}

species dog_a parent: dog{ // red dog
	aspect default {
		draw shape at: location color: #red;
	}
}

species dog_s parent: dog{ // yellow dog
	aspect default {
		draw shape at: location color: #yellow;
	}
}


species sheep skills: [pedestrian]{
	rgb color <- #black;
	
	float urgency <- 0.5;
	float pred_distance <- P_pred_distance ;
	float herd_distance <- P_herd_distance;
	float food_distance <- P_food_distance;
	float cell_distance <- P_cell_distance;
	int min_nearby <- P_min_nearby;  
	int max_nearby <- P_max_nearby;

	bool alert <- false;
	
	float speed <- urgency*15 #km/#h min: 2 #km/#h  max: 15 #km/#h;
	point current_target;
	string result ;
	
	bool tendency_right_up <- rnd_choice([true::0.5,false::0.5]);

	
	reflex change_target_urgency{
		result <- nil;
		// nearby predators (just the dogs)
		list<dog> nearby_dogs <- list(dog_a at_distance pred_distance) + list(dog_s at_distance pred_distance);
	    // closest cell that is significantly trampled
		parcel closest_trampled <- parcel where (each.trampledness <= P_trampledPathThreshold) closest_to location;
		list<sheep> nearby_sheep;  // sheeps that is inside a radius
		list<sheep> nearest_sheeps;  //  10 nearest sheep
		parcel nearestFood;
		
		if not empty(nearby_dogs){  // if there is a dog nearby
			result <- "condition1";
		} 
		
		else {
			// sheeps that is inside a radius
			nearby_sheep <- list(sheep - self) at_distance herd_distance;
			//  10 nearest sheep
			nearest_sheeps <- first( 10, list(sheep - self) sort_by(each distance_to(self)) ) ;	
			
			if (length(nearby_sheep) <= min_nearby) or  (length(nearest_sheeps where each.alert != false) >= 5){
				result <- "condition2";  // if too few sheep nearby or nearby sheep are alerted by predator
			}
			
			else {
				 // nearest grid that has food
	        	nearestFood <- parcel where (each.hasFood = true) closest_to location;
	        	if nearestFood != nil and distance_to(nearestFood, location) <= food_distance{
	        		result <- "condition3"; // if there is food nearby
	        	}
	        	
	        	else if (length(nearby_sheep) >= max_nearby) {
	        		result <- "condition4";  // if surrounding area is too crowded
	        	}
			}
		}
		
		if result = "condition1" { // run from the predator
			alert <- true;
			
			point avg_position <- {0, 0};
			loop d over: nearby_dogs{
				avg_position <- avg_position  + d.location;				
			}
			avg_position <- avg_position / length(nearby_dogs);
			
			// more urgency if dog move closer
			urgency <- 1 - 0.5*distance_to(location, avg_position)/pred_distance; 
			current_target <-  location + location - avg_position; 
		    if closest_trampled != nil{
		    	current_target <-(closest_trampled.location +  current_target )/2; 
		    }		
		}
		
		else if result = "condition2"{   // move close to the herd
	    	urgency <- 1- 0.7 *length(nearby_sheep)/ min_nearby;
	        
	        point avg_position <- {0, 0};
	        
	        loop s over: nearest_sheeps {
	            avg_position <- avg_position  + s.location;
	        }
	        avg_position <- avg_position / 10;  // average location of nearby sheep
	        current_target <- (current_target + avg_position) / 2;  // update target location
	        if closest_trampled != nil{
	        	current_target <-(closest_trampled.location +  current_target )/2;
	        }  		
		}
		else if result = "condition3"{  // move towards the food
	    	current_target <- nearestFood.location;
	    	urgency <- 0.5;		
		}
		else if result = "condition4"{  // move to the quadrant which is more open
	      	urgency <- min_nearby/length(nearby_sheep);
	        
	    	int nb_top_right <- length(sheep where (each.location >= location));
	    	int nb_bottom_left <- length(sheep where (each.location <= location));
	    	int nb_top_left <- length(sheep where (each.location.y >= location.y and each.location.x <= location.x));
	    	int nb_bottom_right <- length(sheep where (each.location.y <= location.y and each.location.x >= location.x));
	    	
	    	container listDir <- [nb_top_right,nb_bottom_left,nb_top_left, nb_bottom_right];
	    	int spaciousDirection <- min(listDir);
	    	
	    	if spaciousDirection = nb_top_right{
	    		current_target <- location + {3#m,3#m};
	    	}
	    	
	    	else if spaciousDirection = nb_top_left{
	    		current_target <- location + {3#m,-3#m};
	    	}
	    	
	    	else if spaciousDirection = nb_bottom_left{
	    		current_target <- location + {-3#m,-3#m};
	    	}
	    	
	    	else {
	    		current_target <- location + {-3#m,3#m};
	    	}		
		}
		else{
			current_target <- nil;
		}

        		
	}


	reflex modify_blocked_target{
		if current_target != nil{
//			geometry pathNow <- geometry(path(location,current_target));
			geometry pathNow <- link(location,current_target);
			if not empty ((parcel where (each.hasObstacle = true ))  overlapping pathNow ) {  //where each.shape
				
				float angle  <- angle_between(location,{0,1},current_target);
				// if the direction of current path look kinda vertical --> modify it lean left/ right
				// if the direction of current path look kinda horizontal --> modify it lean up/down
				// it is performed by adding to the x or y axis of the current target point some fixed value
				if tendency_right_up = true{
					if ((45 <= angle and angle <= 135) or (225 <= angle and angle <= 315)){
						current_target <- current_target + {P_modify_target_val#m,0};
						
					}
					
					else {
						current_target <- current_target + {0,P_modify_target_val#m};
					}					
				}
				else {
					if ((45 <= angle and angle <= 135) or (225 <= angle and angle <= 315)){
						current_target <- current_target + {-P_modify_target_val#m,0};
						
					}
					
					else {
						current_target <- current_target + {0,-P_modify_target_val#m};
					}					
				}

			}
		}
		
		if flip(0.001){
			tendency_right_up <- not tendency_right_up;
		}
					
	}

	
	reflex move when: current_target != nil {
		do walk_to target: current_target;
		if (location = current_target){
			current_target <- nil;
		}
		
//		do walk ;
	}	
	
	aspect default {
		
		if display_circle_min_dist and minimal_distance > 0 {
			draw circle(minimal_distance).contour color: #white;
		}
		
		draw triangle(shoulder_length) color: #white rotate: heading + 90.0;
		
		if display_target and current_waypoint != nil {
			draw line([location,current_waypoint]) color: color;
		}	
	}
}


experiment normal_sim type: gui {
	//Pause the experiement when adding obstacles to prevent bugs
	
	parameter "display_free_space" var:display_free_space;
	parameter "display_force" var:display_force;
	parameter "display_target" var:display_target; 
	parameter "display_circle_min_dist" var:display_circle_min_dist;
	parameter "P_shoulder_length" var:P_shoulder_length;
	parameter "P_proba_detour" var:P_proba_detour;
	parameter "P_avoid_other" var:P_avoid_other;
	parameter "P_obstacle_consideration_distance" var:P_obstacle_consideration_distance;
	parameter "P_pedestrian_consideration_distance" var:P_pedestrian_consideration_distance;
	parameter "P_tolerance_target" var:P_tolerance_target;
	parameter "P_use_geometry_target" var:P_use_geometry_target;


	parameter "P_model_type" var:P_model_type among: ["simple", "advanced"]; 

	parameter "P_A_pedestrian_SFM_advanced" var:P_A_pedestrian_SFM_advanced   category: "SFM advanced";
	parameter "P_A_obstacles_SFM_advanced" var:P_A_obstacles_SFM_advanced   category: "SFM advanced";
	parameter "P_B_pedestrian_SFM_advanced" var:P_B_pedestrian_SFM_advanced   category: "SFM advanced";
	parameter "P_B_obstacles_SFM_advanced" var:P_B_obstacles_SFM_advanced   category: "SFM advanced";
	parameter "P_relaxion_SFM_advanced" var:P_relaxion_SFM_advanced    category: "SFM advanced";
	parameter "P_gama_SFM_advanced" var:P_gama_SFM_advanced category: "SFM advanced";
	parameter "P_lambda_SFM_advanced" var:P_lambda_SFM_advanced   category: "SFM advanced";
	parameter "P_minimal_distance_advanced" var:P_minimal_distance_advanced   category: "SFM advanced";


	parameter "nb_sheep" var:nb_sheep category: "Other sheep parameters";
	parameter "P_pred_distance" var:P_pred_distance category: "Other sheep parameters";
	parameter "P_herd_distance" var:P_herd_distance category: "Other sheep parameters";
	parameter "P_food_distance" var:P_food_distance category: "Other sheep parameters";
	parameter "P_cell_distance" var:P_cell_distance category: "Other sheep parameters";
	parameter "P_min_nearby" var:P_min_nearby category: "Other sheep parameters";
	parameter "P_max_nearby" var:P_max_nearby category: "Other sheep parameters";
	parameter "P_trampledPathThreshold" var:P_trampledPathThreshold category: "Other sheep parameters";
	parameter "P_modify_target_val" var:P_modify_target_val category: "Other sheep parameters";
	
	
	parameter "P_food_spawn_rate" var:P_food_spawn_rate max: 1.0 min:0.1 step:0.1 category: "Environmental";
	parameter "P_rate_get_trample" var:P_rate_get_trample max: 0.009 min:0.001 step:0.001  category: "Environmental";
	parameter "P_rate_trample_decay" var:P_rate_trample_decay max: 0.002 min:0.0001 step:0.0002 category: "Environmental";
		


	float minimum_cycle_duration <- 0.2#s;
	output {
		display "sheep movement" type:2d {
//			camera #from_above locked:true;
			event 'a' {ask simulation {do clicka;}}  // click a to control 1 dog
			event 's' {ask simulation {do clicks;}}  // click s to control the other dog
			//Pause the experiement when adding obstacles to prevent bugs
			event 'w' {ask simulation {do make_obstacle;}}   // click w to make obstacles
			event 'e' {ask simulation {do delete_obstacle;}}  // click e to delete an obstacle
			
			event 'r' {ask simulation {do make_path;}}	// click r to make the cell trampled
			event 't' {ask simulation {do delete_path;}}	// click t to make the cell untrampled
			
			graphics "world" {
				draw world color: #white border:#black;
			}


			species parcel aspect:default;

			species dog_a aspect:default;
			species dog_s aspect:default;
			species sheep;
			species obstacle aspect: default;
		}
		
	}
}




