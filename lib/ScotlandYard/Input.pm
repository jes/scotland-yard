package ScotlandYard::Input;

use strict;
use warnings;

use Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(choice number prompt yesno);

sub prompt {
    my ($prompt) = @_;
    $| = 1;
    print "$prompt ";
    my $in = <>;
    die "Goodbye!\n" if !defined $in;
    chomp $in;
    return $in;
}

sub number {
    my ($prompt) = @_;
    while (1) {
        my $answer = prompt($prompt);
        return $answer if $answer =~ /^[0-9]+$/; # no use for negative numbers
    }
}

sub yesno {
    my ($prompt) = @_;
    return choice($prompt, 'yes', 'no') eq 'yes';
}

sub choice {
    my ($prompt, @choices) = @_;
    while (1) {
        my $answer = prompt($prompt);
        for my $choice (@choices) {
            # TODO: don't accept ambiguous input?
            return $choice if $choice =~ /^$answer/;
        }
    }
}

1;
