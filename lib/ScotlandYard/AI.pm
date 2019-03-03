package ScotlandYard::AI;

use strict;
use warnings;

use List::Util qw(shuffle);

use ScotlandYard::Map;

my $SEARCHDEPTH = 2;

sub best_mrx_move {
    my ($pkg, $game, $depth) = @_;
    $depth //= $SEARCHDEPTH;

    if ($depth <= 0) {
        my $s = $pkg->mrx_evaluate($game);
        return (undef, $s);
    }

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

        my ($detective_move, $score) = $pkg->best_detectives_move($newgame, $depth-1);
        if ($score > $bestscore) {
            $bestmove = $m;
            $bestscore = $score;
        }
    }

    return ($bestmove, $bestscore);
}

# return the set of legal detective moves
sub dfs_detective_moves {
    my ($pkg, $game, $i, $move) = @_;
    $i //= 0;
    $move //= [];

    if ($i >= @{ $game->{detectives} }) {
        return ($move);
    }

    my $d = $game->{detectives}[$i];

    my @moves;
    my @adjacent_stations = ScotlandYard::Map->adjacent_stations($d->{station});
    my $has_moves = 0;
    for my $adj (@adjacent_stations) {
        next if $d->{type} ne 'police' && $d->{tickets}{$adj->{type}} <= 0;
        next if grep { $_->[2] == $adj->{station} } @$move; # can't have 2 detectives on same station
        $has_moves = 1;
        my $m = [$d->{colour}, $adj->{type}, $adj->{station}];
        push @moves, $pkg->dfs_detective_moves($game, $i+1, [@$move, $m]);
    }

    if (!$has_moves) {
        # if this detective has no moves, we still need moves from other detectives
        push @moves, $pkg->dfs_detective_moves($game, $i+1, $move);
    }

    return @moves;
}

sub best_detectives_move {
    my ($pkg, $game, $depth) = @_;
    $depth //= $SEARCHDEPTH-1;

    if ($depth <= 0) {
        my $s = $pkg->mrx_evaluate($game);
        return (undef, $s);
    }

    # TODO: don't allow illegal moves (e.g. detective A from 104=>105 and B 105=>104 is impossible)
    my @legal_moves = $pkg->dfs_detective_moves($game);

    my $bestmove;
    my $bestscore = 100000000;
    for my $move (@legal_moves) {
        my $newgame = $game->clone;
        for my $detective_move (@$move) {
            my ($colour, $type, $station) = @$detective_move;
            $newgame->detective_movement($colour, $type, $station);
        }

        # need to test for every station that mr. x could be at
        my $score = -1;
        # we want to find the move that gives the *worst* possible *best* score for mr. x
        for my $mrx_station (@{ $newgame->{mrx_possible_stations} }) {
            $newgame->{mrx_station} = $mrx_station;
            my ($mrx_move, $mrx_score) = $pkg->best_mrx_move($newgame, $depth-1);
            $score = $mrx_score if $mrx_score > $score;
        }

        if ($score < $bestscore) {
            $bestmove = $move;
            $bestscore = $score;
        }
    }

    return ($bestmove, $bestscore);
}

# return a measure of how good this position is for mr. x (larger is better for him)
sub mrx_evaluate {
    my ($pkg, $game) = @_;

    # TODO: incorporate a value for the 2X cards and black tickets

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

my %SHORTEST_PATH;
sub shortest_path {
    my ($pkg, $a, $b, %tickets) = @_;

    return 0 if $a == $b;
    return $SHORTEST_PATH{"$a-$b"} if exists $SHORTEST_PATH{"$a-$b"};

    # TODO: keep track of %tickets and don't allow steps where there aren't enough tickets

    my @q = ([$a, 0]);
    my %visited = ($a => 1);
    while (@q) {
        my ($station, $length) = @{ shift @q };
        for my $adj (ScotlandYard::Map->adjacent_stations($station)) {
            next if $visited{$adj->{station}};
            next if $adj->{type} eq 'ferry'; # detectives can't go on ferries
            if ($adj->{station} == $b) {
                %SHORTEST_PATH = () if keys %SHORTEST_PATH > 100000; # jescache
                $SHORTEST_PATH{"$a-$b"} = $length+1;
                return $length+1;
            }
            $visited{$adj->{station}} = 1;
            push @q, [$adj->{station}, $length+1];
        }
    }

    warn "no path from $a to $b ???\n";
    return 100;
}

1;
