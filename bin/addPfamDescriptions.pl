#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;

my ($iprscan, $arbaOutput, $outputFile);

GetOptions(
    "iprscan=s"    => \$iprscan,
    "arbaOutput=s" => \$arbaOutput,
    "outputFile=s" => \$outputFile,
) or die "Usage: $0 --iprscan <file> --arbaOutput <file> --outputFile <file>\n";

die "Missing required arguments\n" unless $iprscan && $arbaOutput && $outputFile;

# ---------------- Load ARBA results ----------------
open my $ARBA, '<', $arbaOutput or die "Could not open file $arbaOutput: $!";

my %arbaHits;
while (my $line = <$ARBA>) {
    chomp $line;
    my ($proteinId, $desc, $type) = split /\t/, $line;
    $arbaHits{$proteinId} = 1;
}
close $ARBA;

# ---------------- Load IPRscan results ----------------
open my $IPR, '<', $iprscan or die "Could not open file $iprscan: $!";

# Hash: protein → arrayref of [sigAcc, sigDesc]
my %pfamHits;

while (my $line = <$IPR>) {
    chomp $line;

    my ($protein, $md5, $length, $analysis, $sigAcc, $sigDesc,
        $start, $end, $score, $status, $date, $iprAcc) = split /\t/, $line;

    # Only Pfam, and only proteins not found in ARBA
    if ($analysis eq 'Pfam') {
        if (!exists $arbaHits{$protein}) {

            # Initialize arrayref for this protein if needed
            if (!exists $pfamHits{$protein}) {
                $pfamHits{$protein} = [];
            }

            # Store pair of sigAcc + sigDesc (aligned)
            push @{ $pfamHits{$protein} }, [ $sigAcc, $sigDesc ];
        }
    }
}

close $IPR;

# ---------------- Output Results ----------------
open my $OUT, '>', $outputFile or die "Cannot write to $outputFile: $!";

foreach my $protein (sort keys %pfamHits) {

    my %seen;
    my @unique_pairs;

    # Deduplicate pairs based on both fields
    foreach my $pair (@{ $pfamHits{$protein} }) {
        my ($acc, $desc) = @$pair;
        my $key = "$acc|$desc";

        next if $seen{$key}++;
        push @unique_pairs, $pair;
    }

    # Split arrays cleanly and aligned
    my @acc_list  = map { $_->[0] } @unique_pairs;
    my @desc_list = map { $_->[1] } @unique_pairs;

    # Build comma-separated strings
    my $acc_str  = join(",", @acc_list);
    my $desc_str = join(",", @desc_list);

    # Output: proteinID  accs  descs
    print $OUT "$protein\t$acc_str\t$desc_str\n";
}

close $OUT;

exit 0;
