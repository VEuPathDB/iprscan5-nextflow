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
    my %unique_desc;
    my %unique_rules;

    # Choose analysis in priority order
    foreach my $analysis (@priority) {
        next unless exists $gene_data{$geneId}{$analysis};

        # Collect all descriptions and rules
        my %desc_tmp;
        my %rule_tmp;

        foreach my $rule (keys %{$gene_data{$geneId}{$analysis}}) {
            $rule_tmp{$rule} = 1;
            foreach my $desc (keys %{$gene_data{$geneId}{$analysis}{$rule}}) {
                $desc_tmp{$desc} = 1;
            }
        }

        # Prefer analyses with textual descriptions
        my @text_desc = grep { /[A-Za-z]/ } keys %desc_tmp;

        if (@text_desc) {
            %unique_desc  = map { $_ => 1 } @text_desc;
            %unique_rules = %rule_tmp;
            $chosen_analysis = $analysis;
            last;
        } else {
            # fallback if only EC numbers
            %unique_desc  = %desc_tmp;
            %unique_rules = %rule_tmp;
            $chosen_analysis = $analysis;
        }
    }

    my @descriptions = sort keys %unique_desc;
    my @rules        = sort keys %unique_rules;

    die "Gene $geneId has no descriptions!" unless @descriptions;

    my $full_description = join(", ", @descriptions);
    my $full_rules       = join(", ", @rules);

    print $OUT join("\t",
        $geneId,
        $full_description,
        $chosen_analysis,
        $full_rules
    ), "\n";
}

close $OUT;

print "✅ Reformatted output written to $outputFile\n";
