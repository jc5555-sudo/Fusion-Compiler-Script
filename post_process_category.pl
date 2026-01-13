#!/usr/bin/perl
use strict;
use warnings;

die "Usage: $0 <input1.csv> [input2.csv ...]\n" unless @ARGV;

foreach my $input (@ARGV) {
    process_file($input);
}

print "Done. All files processed.\n";

# ==================================================
sub process_file {
    my ($input) = @_;

    my $output = "post_process_$input";

    open my $IN,  '<', $input  or die "Cannot open $input\n";
    open my $OUT, '>', $output or die "Cannot write $output\n";

    my %groups;
    my $current_net;
    my @current_pins;

    # ---------------------------
    # Copy header unchanged
    # ---------------------------
    while (my $line = <$IN>) {
        print $OUT $line;
        last if $line =~ /^Net,/;
    }

    # ---------------------------
    # Classification rules
    # ORDER MATTERS
    # ---------------------------
    sub classify_group {
        my ($net, $pins_ref) = @_;

        my $text = $net . " " . join(" ", @$pins_ref);

        # 1️⃣ SRAM (highest priority)
        return "SRAM"
            if $text =~ /nibble/i;

        # 2️⃣ Power Switch
        return "Power_Switch"
            if $text =~ /piso_secure.*\/power_ack_signals.*/i;

        # 3️⃣ Level Shifter
        return "Level_Shifter"
            if $text =~ /bitsecure_.*_power_ack_signals.*/i;

        # 4️⃣ Buffers
        return "BUF"
            if $text =~ /(HFSBUF|ZBUF|BUF_)/i;

        # 5️⃣ Inverters
        return "INV"
            if $text =~ /(HFSINV|INV_)/i;

        # 6️⃣ Memory-facing logic (explicit only)
        return "mem"
            if $text =~ /(sync_datafrommem|pout2mem|addr2mem|\bmem\b)/i;

        # 7️⃣ Fallback
        return "others";
    }

    sub flush_group {
        return unless defined $current_net;
        my $cat = classify_group($current_net, \@current_pins);
        push @{ $groups{$cat} }, [ $current_net, [ @current_pins ] ];
        undef $current_net;
        @current_pins = ();
    }

    # ---------------------------
    # Parse NET + PIN groups
    # ---------------------------
    while (my $line = <$IN>) {
        chomp $line;
        next unless $line;

        if ($line =~ /^PIN:/) {
            push @current_pins, $line;
        } else {
            flush_group();
            $current_net = $line;
        }
    }
    flush_group();

    close $IN;

    # ---------------------------
    # Output grouped data
    # SRAM first, others last
    # ---------------------------
    for my $cat (qw(SRAM Power_Switch Level_Shifter BUF INV mem others)) {
        next unless exists $groups{$cat};
        print $OUT "\n*$cat*\n";
        for my $grp (@{ $groups{$cat} }) {
            my ($net, $pins) = @$grp;
            print $OUT "$net\n";
            print $OUT "$_\n" for @$pins;
        }
    }

    close $OUT;

    print "Processed: $input -> $output\n";
}

