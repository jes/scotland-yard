package ScotlandYard::AI;

use strict;
use warnings;

use List::Util qw(shuffle);

use ScotlandYard::Map;

sub best_mrx_move {
    my ($pkg, $game) = @_;

    my @stations = shuffle(ScotlandYard::Map->adjacent_stations($game->{mrx_station}));

    my @legal_moves;

    # move to first station that is a legal move
    # TODO: abstract this into minimax search
    for my $s (@stations) {
        next if $s->{type} eq 'ferry' && $game->{black_tickets} <= 0;
        next if $game->station_has_detective($s->{station});

        my $type = $s->{type};
        $type = 'black' if $type eq 'ferry';
        push @legal_moves, {type => $type, station => $s->{station}};
        push @legal_moves, {type => 'black', station => $s->{station}} if $game->{black_tickets} && $type ne 'black';
    }

    my $bestmove;
    my $bestscore = -1;

    for my $m (@legal_moves) {
        my $newgame = $game->clone;
        $newgame->mrx_movement($m->{type});
        $newgame->{mrx_station} = $m->{station};

        # TODO: minimax search

        my $score = $pkg->mrx_evaluate($newgame);
        if ($score > $bestscore) {
            $bestmove = $m;
            $bestscore = $score;
        }
    }

    return ($bestmove, $bestscore);
}

sub mrx_evaluate {
    my ($pkg, $game) = @_;

    # TODO: incorporate some measure of the uncertainty level that the detectives have in
    # mr. x's location; also incorporate a value for the 2X cards and black tickets

    my $possible_places = @{ $game->{mrx_possible_stations} };
    my $minshortest = 1000;
    my $sum = 0;

    # just return sum of shortest paths from each detective to current mr. x location
    for my $d (@{ $game->{detectives} }) {
        my $len = $pkg->shortest_path($d->{station}, $game->{mrx_station}, %{ $d->{tickets} });
        $sum += $len;
        $minshortest = $len if $len < $minshortest;
    }

    return $minshortest+$sum/10+$possible_places/10;
}

sub shortest_path {
    my ($pkg, $a, $b, %tickets) = @_;

    # TODO: keep track of %tickets and don't allow steps where there arne't enough tickets

    my @q = ([$a, 0]);
    my %visited = ($a => 1);
    while (@q) {
        my ($station, $length) = @{ shift @q };
        for my $adj (ScotlandYard::Map->adjacent_stations($station)) {
            next if $visited{$adj->{station}};
            next if $adj->{type} eq 'ferry'; # detectives can't go on ferries
            return $length+1 if $adj->{station} == $b;
            $visited{$adj->{station}} = 1;
            push @q, [$adj->{station}, $length+1];
        }
    }

    warn "no path from $a to $b ???\n";
    return 100;
}

1;
