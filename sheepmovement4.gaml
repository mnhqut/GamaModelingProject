/**
* Name: sheepmovement4
* Based on the internal empty template. 
* Author: minh
* Tags: 
*/


model sheepmovement4


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
	

	int nb_sheep <- 50;

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
	float food_spawn_rate <- 0.5 max: 1.0 min:0.1;
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
	
	reflex get_trample {
		list<sheep> sheepsInGrid <- sheep where (each overlaps self);
		// the cell get trample by sheep
		loop s over: sheepsInGrid {
			trampledness <- trampledness - s.speed/300;
		}
		 // the trampledness being decayed
		if trampledness < 0.94{
			trampledness <- trampledness + 0.001;
		}
		
		// change color from light brown to deep brown based on trampledness
		color <- rgb(trampledness * 202.0, trampledness * 132.0, trampledness * 60.0);

	
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
	float pred_distance <- 20#m;
	float herd_distance <- 10#m;
	float food_distance <- 7#m;
	float cell_distance <- 8#m;
	int min_nearby <- 5;  
	int max_nearby <- 10;

	bool alert <- false;
	
	float speed <- urgency*15 #km/#h min: 2 #km/#h  max: 15 #km/#h;
	point current_target;
	
	reflex change_target_urgency{

		// nearby predators (just the dogs)
        list<dog> nearby_dogs <- list(dog_a at_distance pred_distance) + list(dog_s at_distance pred_distance);
        // sheeps that is inside a radius
        list<sheep> nearby_sheep <- list(sheep - self) at_distance herd_distance;
        //  10 nearest sheep
        list<sheep> nearest_sheeps <- first( 10, list(sheep - self) sort_by(each distance_to(self)) ) ;	
        // nearest grid that has food
        parcel nearestFood <- parcel where (each.hasFood = true) closest_to location;
        // closest cell that is significantly trampled
		parcel closest_trampled <- parcel where (each.trampledness <= 0.7) closest_to location;
        
        // alert when being chased by dog      
        alert <- false;
        
		// if a dog is nearby
		if not empty(nearby_dogs) {
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
		
		
		// if the nearest sheeps are alerted, this one would also move to follow even when it is not directly near the dog
        // If the number of nearby sheep is <=  min_nearby (too far away from the herd), it should move closer

        else if (length(nearby_sheep) <= min_nearby) or  (length(nearest_sheeps where each.alert != false) >= 5) {
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
        
        // if the sheep see there is food nearby, it will come to the food

       else if nearestFood != nil and distance_to(nearestFood, location) <= food_distance{
        	current_target <- nearestFood.location;
        	urgency <- 0.5;
        }
        
        // if the area around a sheep is too crowded, it move away

        else if (length(nearby_sheep) >= max_nearby){
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


	float minimum_cycle_duration <- 0.2#s;
	output {
		display "sheep movement" type:2d {
//			camera #from_above locked:true;
			event 'a' {ask simulation {do clicka;}}  // click a to control 1 dog
			event 's' {ask simulation {do clicks;}}  // click s to control the other dog
			event 'w' {ask simulation {do make_obstacle;}}   // click w to make obstacles
			event 'e' {ask simulation {do delete_obstacle;}}  // click e to delete an obstacle
			
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




