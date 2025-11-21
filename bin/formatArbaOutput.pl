#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;

my ($arbaOutput, $outputFile);

GetOptions(
    "arbaOutput=s" => \$arbaOutput,
    "outputFile=s" => \$outputFile,
) or die "Usage: $0 --arbaOutput <file> --outputFile <file>\n";

die "Missing required arguments\n" unless $arbaOutput && $outputFile;

open(my $ARBA, '<', $arbaOutput) or die "Could not open file $arbaOutput: $!";

# Store descriptions and rules per gene and analysis
my %gene_data;
my @genes_seen;

while (<$ARBA>) {
    chomp;
    my ($geneId, $desc, $rule, $analysis) = split /\t/;

    # Skip if we already have the same description for this gene-analysis-rule combo
    next if exists $gene_data{$geneId}{$analysis}{$rule}{$desc};

    $gene_data{$geneId}{$analysis}{$rule}{$desc} = 1;
    push @genes_seen, $geneId unless exists $gene_data{$geneId}{_seen};
    $gene_data{$geneId}{_seen} = 1;
}
close $ARBA;

open(my $OUT, '>', $outputFile) or die "Could not open file $outputFile: $!";

# Define analysis priority: FunFam > PANTHER > InterPro
my @priority = ('FunFam id', 'PANTHER id', 'InterPro id');

foreach my $geneId (@genes_seen) {
    my $chosen_analysis;
    my @descriptions;

    # Select analysis to use based on priority and presence of textual description
    foreach my $analysis (@priority) {
        if (exists $gene_data{$geneId}{$analysis}) {
            # Collect all unique descriptions across all rules for this analysis
            my %unique_desc;
            for my $rule (keys %{$gene_data{$geneId}{$analysis}}) {
                for my $desc (keys %{$gene_data{$geneId}{$analysis}{$rule}}) {
                    $unique_desc{$desc} = 1;
                }
            }
            # Prefer analysis that has at least one description with letters
            my @text_desc = grep { /[A-Za-z]/ } keys %unique_desc;
            if (@text_desc) {
                @descriptions = @text_desc;
                $chosen_analysis = $analysis;
                last;
            } else {
                # fallback if only EC numbers present
                @descriptions = keys %unique_desc;
                $chosen_analysis = $analysis;
            }
        }
    }

    die "Gene $geneId has no descriptions!" unless @descriptions;

    # Join unique descriptions with comma
    my $full_description = join(", ", @descriptions);

    print $OUT join("\t", $geneId, $full_description, $chosen_analysis), "\n";
}

close $OUT;

print "✅ Reformatted output written to $outputFile\n";
