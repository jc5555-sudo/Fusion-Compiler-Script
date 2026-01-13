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

    # Capture violation count
    if ($line =~ /Number of (max_transition|max_capacitance) violation\(s\):\s+(\d+)/) {
        my ($t, $cnt) = ($1, $2);
        my $key = "${t}_${mode}";
        $violation_count{$key} = $cnt;
        next;
    }

    # Skip noise
    next if $line =~ /^\s*-{5,}/;
    next if $line =~ /^\s*PIN\s*:/;

    # Net-level violation
    if ($line =~ /^\s*(\S+)\s+([0-9.]+)\s+([0-9.]+)\s+(-?[0-9.]+)\s+\((\w+)\)/) {

        my ($net, $req, $act, $slack, $viol) =
           ($1, $2, $3, $4, $5);

        my $outfile = "${type}_${mode}.csv";
        my $key = "${type}_${mode}";

        # Open file if needed
        if (!exists $fh{$outfile}) {
            open($fh{$outfile}, '>', $outfile)
                or die "Cannot write $outfile\n";
            $fh{$outfile} = $fh{$outfile};
        }

        # Write title block ONCE
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

        print {$fh{$outfile}}
          "$net,$req,$act,$slack,$viol\n";
    }
}

close $IN;

# Append violation count at END of each file
for my $outfile (keys %fh) {
    my ($t, $m) = $outfile =~ /(max_\w+)_(\S+)\.csv/;
    my $key = "${t}_${m}";

    if (exists $violation_count{$key}) {
        print {$fh{$outfile}} "\nTotal $t violations,$violation_count{$key}\n";
    }

    close $fh{$outfile};
}

print "Done. CSV files generated with violation counts.\n";

