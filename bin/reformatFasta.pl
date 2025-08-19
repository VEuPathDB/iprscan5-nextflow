#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;

my ($fasta,$outputFile,$abbrev,$taxID);

&GetOptions("abbrev=s"=> \$abbrev,
            "taxID=s"=> \$taxID,
            "fasta=s"=> \$fasta,
            "outputFile=s"=> \$outputFile
           );

open(my $input, '<', $fasta) || die "Could not open file $fasta: $!";
open(OUT, '>', $outputFile) || die "Could not open file $outputFile: $!";

while (my $line = <$input>) {
    chomp $line;
    if ($line =~ /^>(\S+).*/) {
        my $seqId = $1;
        print OUT ">vp|${seqId}|${seqId}_gene my protein function OS=$abbrev OX=$taxID\n";
    }
    else {
        print OUT "$line\n";
    }
}

1;
