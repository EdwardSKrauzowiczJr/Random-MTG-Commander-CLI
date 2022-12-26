 #! /usr/bin/perl
 
 # Author: Edward S. Krauzowicz, Jr.
 # Date:   12/24/2022
 # Purpose: A small CLI program that is used to randomly select a legal Magic: the Gathering commander using the Scryfall API.
 
 use strict;
 use warnings;
 use v5.010;
 
 use open ":std", ":encoding(UTF-8)";
 require HTTP::Request;
 require LWP::UserAgent;

 use JSON;

 use lib ".";
 use MTGCard;
 
 #user agent for making network calls
 my $agent = new LWP::UserAgent(agent=> "Mozilla/5.0", cookie_jar=>{});;
 
 #api endpoints + query strings
 my $SCRYFALL_API_BASE = "https://api.scryfall.com/";
 my $SCRYFALL_API_CARD_SEARCH = "cards/search?q=";
 my $SCRYFALL_API_LEGAL_IN_COMMANDER_Q = "+legal%3Acommander";
 my $SCRYFALL_API_ABLE_TO_BE_COMMANDER_Q = "+%28%28type%3Acreature+type%3Alegendary%29+OR+%28oracle%3A%22~+can+be+your+commander.%22%29%29";
 my $SCRYFALL_API_COLOR_IDENTITY_Q;

 #color order hash for ordering of entered color identity
 #done for purpose of using entered color identity as key in fetchedColors
 my %COLOR_ORDER = ("W" => 0,
                    "U" => 1,
                    "B" => 2,
                    "R" => 3,
                    "G" => 4);
 
 #key: valid, sorted MTG color
 #value: array with structure (cardset from scryfall, current position in card array, generated card objects)
 #used as a cache to avoid hitting API endpoint multiple times as that is a costly transaction
 my %fetchedColors = ();
 
 #constants used to access array in fetchedColors
 my $CARDSET_POSITION = 0;
 my $CARD_OBJECTS_POSITION = 1;
 
 say "Welcome to the MTG RANDOM COMMANDER FETCHER.";
 say "The purpose of this program is to fetch a random MTG card that can serve as your commander.";
 say "You may enter Q to quit the program at any time.";
 
 my $running = 1;
 while ($running) {
  
    my $colorIdentity;
    
    my $invalid = 1;
    while ($invalid) {
     
       #either some combo of WUBRG or C.
       say "Please enter either a valid MTG color combination, or C for colorless.";
       $colorIdentity = uc <STDIN>;
       chomp $colorIdentity;
    
       &checkForExit($colorIdentity);

       #pattern will match any unordered combination of WUBRG
       if($colorIdentity !~ /\b(?!\w*(\w)\w*\1)[WUBRG]+\b/ and $colorIdentity !~ /\bC\b/) {
          say "Invalid color identity.";
          say "Valid MTG colors are (W)(U)(B)(R)(G) in any combination, or (C).";
       } else {
          $invalid = 0;
       }
       
    }        
          
    &orderColors($colorIdentity);
          
    #if the color identity has been searched before, refer to data stored in memory & skip
    #making another expensive API call
    
    #otherwise make initial API call to fetch full set of commanders matching query
    if (exists $fetchedColors{$colorIdentity}) {
     
       say "Would you like to see your previously randomly rolled commanders in $colorIdentity? (Y/N)";
       
       my $selection = uc <STDIN>;
       chomp $selection;
       &checkForExit($selection);
       
       while ($selection ne "Y" and $selection ne "N") {
          say "Please enter (Y/N)";
          $selection = uc <STDIN>;
          chomp $selection;
          &checkForExit($selection);
       }
       
       if ($selection eq "Y") {
          
          my $seenCommanders = @{$fetchedColors{$colorIdentity}}[$CARD_OBJECTS_POSITION];
          
          my $index = 0;
          foreach my $commander (@{$seenCommanders}) {
             say (($index + 1) . ". " . $commander->getCardName());
             $index++;
          }
          
          say "Enter either a number to display the associated commander again, or (X) to leave this menu.";
          
          my $invalid = 1;
          while ($invalid) {
            
             my $selection = uc <STDIN>;
             chomp $selection;
             &checkForExit($selection);
             
             if ($selection eq "X") {
                say "Returning to main menu.";
                $invalid = 0;
             } elsif (($selection - 1) >= 0 and ($selection - 1) < (scalar @{$seenCommanders})) {
                say @{@{$fetchedColors{$colorIdentity}}[$CARD_OBJECTS_POSITION]}[$selection - 1]->prettyPrint();
                $invalid = 0;
             } else {
                say "Selection out of bounds. Please enter a number between 1 and $selection.";
             }
             
          }
          
          
       } else {
        
          my $cardset = $fetchedColors{$colorIdentity}[$CARDSET_POSITION];
        
          if (scalar @{$cardset} > 0) {
           
             say "Rolling a new commander.";
          
             my $randomRolls = 1;
             my $randInTotalRemainingCards = int(rand((scalar @{$cardset}) - $randomRolls));
          
             my $invalid = 1;
             my $cardJson;
             while ($invalid) {
           
                $cardJson = @{$cardset}[$randInTotalRemainingCards];
                splice(@{$cardset}, $randInTotalRemainingCards, 1);
             
                $invalid = &checkForValidCard($cardJson);
             
                if (!$invalid) {
                    $randomRolls++;
                    $randInTotalRemainingCards = int(rand((scalar @{$cardset}) - $randomRolls));
                }
            
             }
       
             my $cardObject = new MTGCard($cardJson->{"name"},
                                          $cardJson->{"mana_cost"},
                                          $cardJson->{"type_line"},
                                          $cardJson->{"oracle_text"},
                                          $cardJson->{"power"},
                                          $cardJson->{"toughness"});
       
             $cardObject->prettyPrint();
       
             push @{@{$fetchedColors{$colorIdentity}}[$CARD_OBJECTS_POSITION]}, $cardObject;
             
          } else {
             say "No new commanders to roll."
          }
          
       }
            
    } else {
             
       $SCRYFALL_API_COLOR_IDENTITY_Q = "+commander%3D" . $colorIdentity;
        
       my $response = $agent->get($SCRYFALL_API_BASE .
                                  $SCRYFALL_API_CARD_SEARCH .
                                  $SCRYFALL_API_COLOR_IDENTITY_Q .
                                  $SCRYFALL_API_LEGAL_IN_COMMANDER_Q .
                                  $SCRYFALL_API_ABLE_TO_BE_COMMANDER_Q)->content;
              
       my $responseJson = decode_json($response);
       
       my $randomRolls = 1;
       my $randInTotalCards = int(rand(($responseJson->{"total_cards"}) - $randomRolls));
       
       my $invalid = 1;
       my $cardJson;
       while ($invalid) {
           
          $cardJson = $responseJson->{"data"}[$randInTotalCards];
          splice(@{$responseJson->{"data"}}, $randInTotalCards, 1);
             
          $invalid = &checkForValidCard($cardJson);
          
          if (!$invalid) {
             $randomRolls++;
             $randInTotalCards = int(rand((scalar @{$responseJson->{"data"}}) - $randomRolls));
          }
            
       }
              
       my $cardObject = new MTGCard($cardJson->{"name"},
                                    $cardJson->{"mana_cost"},
                                    $cardJson->{"type_line"},
                                    $cardJson->{"oracle_text"},
                                    $cardJson->{"power"},
                                    $cardJson->{"toughness"});
    
       $cardObject->prettyPrint();
          
       $fetchedColors{$colorIdentity} = [$responseJson->{"data"}, [$cardObject]];
           
      }
 }
 
 #a simple implementation of insertion sort due to the small, constant size of our data.
 #reorders 
 sub orderColors {
    my ($colorString) = @_;
    
    my @colorArray = split(//, $colorString); 
    
    my $length = scalar(@colorArray);
    my $i = 1;
    while ($i < $length) {
     
        my $iElement = $colorArray[$i];
        my $j = $i - 1;
        
        while ($j >= 0 and $COLOR_ORDER{$colorArray[$j]} > $COLOR_ORDER{$iElement}) {
            @colorArray[$j + 1] = $colorArray[$j];
            $j -= 1;
        }
        
        @colorArray[$j + 1] = $iElement;
        $i += 1;
        
    }
    
    $_[0] = join("", @colorArray);
 }
 
 #checks to ensure the card being processed is a single faced creature
 sub checkForValidCard {
 
    my ($value) = @_;
    
    #if loyalty is present, planeswalker
    #if card_faces is present, dual faced
    #neither card type is supported at the moment so return a 1
    if (defined $value->{"loyalty"} or defined $value->{"card_faces"}) {
        return 1;
    }
    
    return 0;   
 
 }
 
 #checks for exit command to program
 sub checkForExit {
    my ($value) = @_;
    
    if ($value eq 'Q') {
       exit();
    }
 }