#!/usr/bin/perl
use strict;
use warnings;

die "Usage: perl post_process.pl *.csv\n" unless @ARGV;

# ===============================
# Classification
# ===============================
sub classify_group {
    my ($net, $pins_ref) = @_;
    my $text = join " ", $net, @$pins_ref;

    return "SRAM"          if $text =~ /nibble/i;
    return "Power_Switch"  if $text =~ /piso_secure.*power_ack_signals/i;
    return "Level_Shifter" if $text =~ /bit_secure_.*power_ack_signals/i;
    return "INV"           if $text =~ /(HFSINV|_INV_)/i;
    return "BUF"           if $text =~ /(HFSBUF|ZBUF|BUF_)/i;
    return "mem"
        if $text =~ /(mem|sync_datafrommem|pout2mem|addr2mem)/i
        && $text !~ /ISO_SIPO/i;

    return "others";
}

# ===============================
# HTML helpers
# ===============================
sub html_header {
    return <<'HTML';
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
body { font-family: Arial; }
table { border-collapse: collapse; width: 100%; }
th, td { border: 1px solid #aaa; padding: 4px; }
th { background: #ddd; }
tr.NET { background: #eef; font-weight: bold; }
</style>
</head>
<body>
<table>
<tr>
<th>Category</th><th>Type</th><th>Name</th>
<th>Required</th><th>Actual</th><th>Slack</th><th>Violation</th>
</tr>
HTML
}

sub html_footer {
    return "</table></body></html>\n";
}

# ===============================
# Flush helper (CORRECT)
# ===============================
sub flush_group {
    my ($CSV, $HTML, $net, $pins_ref, $rows_ref) = @_;
    return unless defined $$net;

    my $cat = classify_group($$net, $pins_ref);

    for my $r (@$rows_ref) {
        my ($type, $name, $req, $act, $slack, $viol) = @$r;

        print $CSV join(",", $cat, $type, $name, $req, $act, $slack, $viol) . "\n";

        print $HTML "<tr class='$type'><td>$cat</td><td>$type</td>"
          . "<td>$name</td><td>$req</td><td>$act</td>"
          . "<td>$slack</td><td>$viol</td></tr>\n";
    }

    $$net = undef;
    @$pins_ref = ();
    @$rows_ref = ();
}

# ===============================
# Main loop
# ===============================
for my $file (@ARGV) {

    next if $file =~ /^post_process_/;
    next unless -f $file;

    my $out_csv  = "post_process_$file";
    (my $out_html = $out_csv) =~ s/\.csv$/.html/;

    open my $IN, '<', $file or die "Cannot open $file\n";
    open my $CSV, '>', $out_csv or die $!;
    open my $HTML,'>', $out_html or die $!;

    print $CSV "Category,Type,Name,Required,Actual,Slack,Violation\n";
    print $HTML html_header();

    my ($current_net, @current_pins, @rows);

    while (my $line = <$IN>) {
        chomp $line;
        next unless $line =~ /,/;
        next if $line =~ /^(Mode|Scenario|Constraint|Total)/i;

        my @f = split /,/, $line;
        next unless @f >= 5;

        my ($name, $req, $act, $slack, $viol) = @f[0..4];

        if ($name =~ /^PIN:/) {
            push @current_pins, $name;
            push @rows, ["PIN", $name, $req, $act, $slack, $viol];
        } else {
            flush_group($CSV, $HTML, \$current_net, \@current_pins, \@rows);
            $current_net = $name;
            push @rows, ["NET", $name, $req, $act, $slack, $viol];
        }
    }

    flush_group($CSV, $HTML, \$current_net, \@current_pins, \@rows);

    print $HTML html_footer();

    close $IN;
    close $CSV;
    close $HTML;

    print "Processed: $file -> $out_csv , $out_html\n";
}

print "Done. ALL files processed correctly.\n";

