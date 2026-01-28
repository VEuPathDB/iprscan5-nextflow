#!/usr/bin/env perl
use strict;
use warnings;

use Getopt::Long;

my ($fasta, $interpro, $output);
GetOptions(
    "fasta=s"    => \$fasta,
    "interpro=s" => \$interpro,
    "output=s"   => \$output,
) or die "Usage: $0 --fasta <file> --interpro <file> --output <file>\n";

die "Missing --fasta\n"    unless $fasta;
die "Missing --interpro\n" unless $interpro;
die "Missing --output\n"   unless $output;

# ------------------------------------------------------------
# STEP 1 — Read FASTA and store longest protein per gene
# ------------------------------------------------------------

my %longest;   # gene => { prot_id => ..., length => ... }

open(my $FA, "<", $fasta) or die "Cannot read $fasta: $!\n";

my ($header, $seq) = ("", "");

while (<$FA>) {
    chomp;
    if (/^>(\S+)/) {
        # Process previous entry
        if ($header && $seq) {
            process_fasta_entry($header, $seq, \%longest);
        }
        $header = $1;   # protein ID like HpaG800000:RNA-p1
        $seq    = "";
    } else {
        $seq .= $_;
    }
}

# Last entry
process_fasta_entry($header, $seq, \%longest) if ($header && $seq);

close $FA;

# ------------------------------------------------------------
# STEP 2 — Read InterPro output and print only lines matching longest proteins
# ------------------------------------------------------------

open(my $IN, "<", $interpro) or die "Cannot read $interpro: $!\n";
open(my $OUT, ">", $output) or die "Cannot write $output: $!\n";

while (<$IN>) {
    chomp;
    my @fields = split(/\t/, $_);
    my $prot   = $fields[0];

    # Extract gene prefix before colon
    # HpaG806097:RNA-p1  →  HpaG806097
    my $gene = &extract_gene_id($prot);

    if ($longest{$gene} && $longest{$gene}{prot_id} eq $prot) {
        print $OUT $_, "\n";
    }
}

close $IN;
close $OUT;

exit(0);

# ------------------------------------------------------------
# Subroutine: process a fasta entry, track longest per gene
# ------------------------------------------------------------
sub process_fasta_entry {
    my ($prot_id, $seq, $href) = @_;
    return unless $prot_id;

    # Remove trailing metadata ("length=..." etc.)
    my ($base) = $prot_id =~ /^([^ \t]+)/;

    # Determine gene ID
    my $gene;
    if ($base =~ /:/) {
        ($gene) = split(/:/, $base, 2);
    } else {
        ($gene) = split(/-/, $base, 2);
    }

    my $len = length($seq);

    if (!exists $href->{$gene} || $len > $href->{$gene}{length}) {
        $href->{$gene} = {
            prot_id => $base,   # store clean ID, not whole header
            length  => $len
        };
    }
}

sub extract_gene_id {
    my ($id) = @_;

    # Remove anything after the first space (in case full FASTA header was passed)
    $id =~ s/\s.*$//;

    # CASE 1 — if it contains a colon: use everything before the colon
    if ($id =~ /:/) {
        $id =~ s/:.*$//;
        return $id;
    }

    # CASE 2 — dash format (AAEL026375-PA, PBANKA_0000101.1-p1)
    if ($id =~ /-/) {
        $id =~ s/-[^-]+$//;       # remove everything after FINAL dash
        return $id;
    }

    # fallback
    return $id;
}
