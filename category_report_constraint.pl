#!/usr/bin/perl
use strict;
use warnings;

my $input = shift || die "Usage: $0 <pt_report.txt>\n";

my ($mode, $corner, $scenario, $type);

my %fh;
my %section_written;
my %violation_count;

open(my $IN, '<', $input) or die "Cannot open $input\n";

while (my $line = <$IN>) {
    chomp $line;

    # Mode / Corner
    if ($line =~ /^\s*Mode:\s+(\S+)\s+Corner:\s+(\S+)/) {
        ($mode, $corner) = ($1, $2);
        next;
    }

    # Scenario
    if ($line =~ /^\s*Scenario:\s+(\S+)/) {
        $scenario = $1;
        next;
    }

    # Constraint type
    if ($line =~ /^\s*(max_transition|max_capacitance)\s*$/) {
        $type = $1;
        next;
    }

    # Violation count
    if ($line =~ /Number of (max_transition|max_capacitance) violation\(s\):\s+(\d+)/) {
        $violation_count{"${1}_${mode}"} = $2 if defined $mode;
        next;
    }

    # Skip separators
    next if $line =~ /^\s*-{5,}/;

    # Safety guard
    next unless defined $mode && defined $type;

    my $outfile = "${type}_${mode}.csv";

    # Open file if needed
    if (!exists $fh{$outfile}) {
        open($fh{$outfile}, '>', $outfile)
            or die "Cannot write $outfile\n";
        $fh{$outfile} = $fh{$outfile};
    }

    # Write header once
    if (!$section_written{$outfile}) {
        print {$fh{$outfile}} "Mode: $mode  Corner: $corner\n";
        print {$fh{$outfile}} "Scenario: $scenario\n";
        print {$fh{$outfile}} "Constraint: $type\n\n";

        if ($type eq 'max_transition') {
            print {$fh{$outfile}}
              "Net,Required Transition,Actual Transition,Slack,Violation\n";
        } else {
            print {$fh{$outfile}}
              "Net,Required Capacitance,Actual Capacitance,Slack,Violation\n";
        }

        $section_written{$outfile} = 1;
    }

    # ---------------- NET row ----------------
    if ($line =~ /^\s*(\S+)\s+([0-9.]+)\s+([0-9.]+)\s+(-?[0-9.]+)\s+\((\w+)\)/) {

        my ($net, $req, $act, $slack, $viol) =
           ($1, $2, $3, $4, $5);

        print {$fh{$outfile}}
          "$net,$req,$act,$slack,$viol\n";

        next;
    }

    # ---------------- PIN row ----------------
    if ($line =~ /^\s*PIN\s*:\s*(\S+)\s+([0-9.]+)\s+([0-9.]+)\s+(-?[0-9.]+)\s+\((\w+)\)/) {

        my ($pin, $req, $act, $slack, $viol) =
           ($1, $2, $3, $4, $5);

        print {$fh{$outfile}}
          "PIN: $pin,$req,$act,$slack,$viol\n";

        next;
    }
}

close $IN;

# Append violation count
for my $outfile (keys %fh) {
    if ($outfile =~ /(max_\w+)_(\S+)\.csv/) {
        my $key = "$1_$2";
        if (exists $violation_count{$key}) {
            print {$fh{$outfile}}
              "\nTotal $1 violations,$violation_count{$key}\n";
        }
    }
    close $fh{$outfile};
}

print "Done. CSV files generated with correct NET/PIN structure.\n";

