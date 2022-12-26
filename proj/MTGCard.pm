# Author: Edward S. Krauzowicz, Jr.
# Date: 12/24/2022
# Purpose: Supporting class for random commander fetcher.

use strict;
use warnings;
use v5.010;

package MTGCard;

my $CORNER_DELIM = ".";
my $H_BORDER_DELIM = "-";
my $V_BORDER_DELIM = "|";

my $INTERIOR_ART_HEIGHT = 12;
my $INTERIOR_HEIGHT = 12;

sub new {

    my $class = shift;
    my $self = {
    
        _cardName => shift,
        _manaCost => shift,
        _typeLine => shift,
        _oracleText => shift,
        
        _power => shift,
        _toughness => shift,
        
        _asciiCard => undef
    
    };
    
    bless $self, $class;
    return $self;

}

sub getCardName {
    my ($self) = @_;
    return $self->{_cardName};
}
sub getManaCost {
    my ($self) = @_;
    return $self->{_manaCost};
}
sub getTypeLine {
    my ($self) = @_;
    return $self->{_typeLine};
}
sub getOracleText {
    my ($self) = @_;
    return $self->{_oracleText};
}
sub getPower {
    my ($self) = @_;
    return $self->{_power};
}
sub getToughness {
    my ($self) = @_;
    return $self->{_toughness};
}

sub getAsciiCard {
    my ($self) = @_;
    return $self->{_asciiCard};
}

sub setAsciiCard {
    my ($self, $value) = @_;
    if (scalar @_ == 2) {
        $self->{_asciiCard} = $value;
    }
    
    return $self->{_asciiCard};
}

#constructs the ascii for a given card.
sub constructAsciiCard {
    
    my ($self) = @_;
    
    my $asciiCard = "";
    
    my $titleLineLength = length($self->getCardName()) + length($self->getManaCost());
    my $typeLineLength = length($self->getTypeLine());
    
    my $INTERIOR_LENGTH = $titleLineLength > $typeLineLength ? ($titleLineLength > 45 ? $titleLineLength : 45) : ($typeLineLength > 45 ? $typeLineLength : 45);
    
    #determine card length based on length of card name + cmc OR type line, whichever is longer
    #determine card height based on length
    $asciiCard .= $CORNER_DELIM . $H_BORDER_DELIM x $INTERIOR_LENGTH . $CORNER_DELIM . "\n";
    $asciiCard .= $V_BORDER_DELIM . $self->getCardName() . " " x ($INTERIOR_LENGTH - $titleLineLength) . $self->getManaCost() . $V_BORDER_DELIM . "\n";
    $asciiCard .= ($V_BORDER_DELIM . " " x $INTERIOR_LENGTH . $V_BORDER_DELIM . "\n") x $INTERIOR_ART_HEIGHT;
    $asciiCard .= $V_BORDER_DELIM . $self->getTypeLine() =~ s/\x{2014}/-/r . " " x ($INTERIOR_LENGTH - $typeLineLength) . $V_BORDER_DELIM . "\n";
    $asciiCard .= $V_BORDER_DELIM . " " x $INTERIOR_LENGTH . $V_BORDER_DELIM . "\n";
    
    #just using split removes the \n character from the text
    #so instead we split abilities first & then split each ability
    #into separate words
    my @splitOracleText = split('\n', $self->getOracleText());
    
    for my $ability (@splitOracleText) {
            
            my @splitAbility = split(' ', $ability);
            
            my $currentCharacterCounter = 0;
            my $currentLine = $V_BORDER_DELIM;
            
            for my $word(@splitAbility) {              
                                
                if($currentCharacterCounter + (length($word)) >= $INTERIOR_LENGTH) {
                    
                    $asciiCard .= $currentLine =~ s/\x{2014}/-/rg =~ s/\x{2022}/>/rg . " " x ($INTERIOR_LENGTH - (length($currentLine) - 1)) . $V_BORDER_DELIM . "\n";
                    
                    $currentLine = $V_BORDER_DELIM . $word . " ";
                    $currentCharacterCounter = length($word) + 1;
                    
                } else {
                    
                    $currentLine .= $word . " ";
                    $currentCharacterCounter += length($word) + 1;
                    
                }
                
            }
            
            #flushes the last line out
            $asciiCard .= $currentLine =~ s/\x{2014}/-/rg =~ s/\x{2022}/>/rg . " " x ($INTERIOR_LENGTH - (length($currentLine) - 1)) . $V_BORDER_DELIM . "\n";
            
        }
    
    $asciiCard .= $V_BORDER_DELIM . " " x $INTERIOR_LENGTH . $V_BORDER_DELIM . "\n";
    
    $asciiCard .= $V_BORDER_DELIM . " " x ($INTERIOR_LENGTH - 6) . $H_BORDER_DELIM x 6 . $V_BORDER_DELIM . "\n";
    $asciiCard .= $V_BORDER_DELIM . " " x ($INTERIOR_LENGTH - 6) . $V_BORDER_DELIM . ($self->getPower() < 10 ? (" " . $self->getPower()) : ($self->getPower())) . "/" . ($self->getPower() < 10 ? (" " . $self->getToughness()) : ($self->getToughness())) . $V_BORDER_DELIM . "\n";
    
    $asciiCard .= $CORNER_DELIM . $H_BORDER_DELIM x $INTERIOR_LENGTH . $CORNER_DELIM . "\n";
    
    $self->setAsciiCard($asciiCard);
    
}

#prints the ascii of a given card. if it's the first time it's being printed
#constructAciiCard() is called first
sub prettyPrint {
    
    my ($self) = @_;
    
    if (!defined($self->{_asciiCard})) {
        $self->constructAsciiCard();
    }
      
    print $self->getAsciiCard();
 
}

1;