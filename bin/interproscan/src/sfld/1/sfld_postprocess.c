#include "sfld_postprocess.h"

// Post-processing of SFLD matches
//
// Requries a search with options:
// hmmsearch -o res.out -A res.aln --domtblout res.dom --noali --cut_ga <SFLD evalue options> SFLD.hmm SEQ.fa 
//
// All three output files are currently required and must be from the same search.
//
// Usage:
// sfld_postprocess -a res.aln -d Ami.dom -O res.hout -s SFLD.annot
//
// where SFLD.annot is the output of sfld_preprocess. It is expected that the three input files were
// all generated from the same search. Other cases will to fail: this is NOT checked for.
//
// Copyright (c) EMBL-EBI 2016.

int main(int argc, char **argv)
{
    struct family *families;
    struct hmmer_dom *dom_hits; // list of hits parsed from tblout
    struct site_match *site_hits = NULL; // list of hits parsed from tblout
    struct no_hit *no_hits = NULL; // list of hits parsed from tblout
    FILE *fout;
    char *hmmerout_fn, *tblout_fn, *alignments_fn, *site_info_fn, *hmmer_path, *output_fn, *format;

    int n_dom_hits = 0;
    int n_site_hits = 0;
    int n_no_hits = 0;
    int i;
    int only_matches = 0;
    int *ali_present = NULL;
    int n_families = 0;
    int n_matched_families = 0;
    char **matched_family_ids;

    hmmer_path = format = hmmerout_fn = output_fn = tblout_fn = alignments_fn = site_info_fn = NULL;

    get_options_post(argc, argv, &only_matches, &hmmer_path, &hmmerout_fn, &output_fn, &tblout_fn, &alignments_fn, &site_info_fn, &format);

    if (! alignments_fn || ! hmmerout_fn || ! tblout_fn || ! site_info_fn) {
        show_help(argv[0]);
        return 0;
    }

    if (output_fn != NULL)
        fout = freopen(output_fn, "w", stdout);

    // parse hmmer out file to find which families have alignments reported
    retrieve_families_with_ali(hmmerout_fn, &ali_present, &n_families);

    // read list of residue-level features
    read_site_data(site_info_fn, &n_families, &families);

    // process alignments and check per residue matches
    identify_site_matches(alignments_fn, families, n_families, &site_hits, &n_site_hits, ali_present, &no_hits, &n_no_hits);

    // parse domain matches
    read_domtblout(tblout_fn, &dom_hits, &n_dom_hits);

    // remove domain hits to families if there are sequences feature which don't match
    filter_no_hits(dom_hits, n_dom_hits, no_hits, n_no_hits);

    // having filtered domains, remove the start-end
    strip_dom_se(dom_hits, n_dom_hits);

    // output all results
    if (format != NULL && ! strcmp(format, "text")) 
        output_dom_sites_as_tab(dom_hits, n_dom_hits, site_hits, n_site_hits);
    else
        output_dom_sites_by_target(dom_hits, n_dom_hits, site_hits, n_site_hits); // i5 format default

    // free space - could tidy this more
    free(ali_present);
    free(tblout_fn);
    free(output_fn);
    if (hmmer_path)
        free(hmmer_path);
    if (format)
        free(format);
    free(hmmerout_fn);
    free(alignments_fn);
    free(site_info_fn);
    free(dom_hits);
    free_site_hits(n_site_hits, site_hits);
    free_no_hits(n_no_hits, no_hits);
    clear_family_data(n_families, families);

    return 0;
}


// Stitch together the domain and site results
void output_dom_sites_by_target(struct hmmer_dom *dom_hits, int n_dom_hits, struct site_match *site_hits, int n_site_hits)
{
    int h = 0;
    int s = 0;
    int cmp;
    char *this_target;
    this_target = strdup("");

    // Sort both domains and sites by target/model so that the results can be interleaved
    // A 2-D array for hits might well have been better
    qsort(dom_hits, n_dom_hits, sizeof(struct hmmer_dom), cmp_dom_target_model);

    // Skip the matches without accessions - these were the ones filtered out earlier
    //while (strlen(dom_hits[h].target_ac) == 0 && strlen(dom_hits[h].model_ac) == 0)
    while (h < n_dom_hits && strlen(dom_hits[h].target_ac) == 0 && strlen(dom_hits[h].model_ac) == 0) 
        h++;

    // Interleave the domain and site hits
    // Work through the stack of (sorted by target) hits and work out whether to output
    // domain hits/site hits/both
    //
    // This could be simplified (fewer lines) but at the moment it's hopefully readable
    while (h < n_dom_hits && s < n_site_hits) {
        // Does the next target have hits to domain/sites/both?
        cmp = strcmp(dom_hits[h].target_ac, site_hits[s].target_ac);
        if (cmp < 0) { // next target in alph order is a domain hit
            free(this_target);
            this_target = strdup(dom_hits[h].target_ac);
            printf("Sequence: %s\n", this_target);
            printf("Domains:\n");
            while (h < n_dom_hits && ! strcmp(dom_hits[h].target_ac, this_target))
                output_dom_hit(dom_hits[h++], 1, 0);
        } else if (cmp > 0) { // next target in alph order is a domain hit
            free(this_target);
            this_target = strdup(site_hits[s].target_ac);
            printf("Sequence: %s\n", this_target);
            printf("Sites:\n");
            while (s < n_site_hits && ! strcmp(site_hits[s].target_ac, this_target))
                output_site_hit(site_hits[s++], 1, 0);
        } else { // next target hits to both domains and sites
            free(this_target);
            this_target = strdup(site_hits[s].target_ac);
            printf("Sequence: %s\n", this_target);
            printf("Domains:\n");
            while (h < n_dom_hits && ! strcmp(dom_hits[h].target_ac, this_target))
                output_dom_hit(dom_hits[h++], 1, 0);
            printf("Sites:\n");
            while (s < n_site_hits && ! strcmp(site_hits[s].target_ac, this_target))
                output_site_hit(site_hits[s++], 1, 0);
        }
        printf("// \n");
    }

    // Clear up any remaining domain hits...
    while (h < n_dom_hits) {
        free(this_target);
        this_target = strdup(dom_hits[h].target_ac);
        printf("// \n");
        printf("Sequence: %s\n", this_target);
        printf("Domains:\n");
        while (h < n_dom_hits && ! strcmp(dom_hits[h].target_ac, this_target))
            output_dom_hit(dom_hits[h++], 1, 0);
    }

    // ... or site hits
    while (s < n_site_hits) {
        free(this_target);
        this_target = strdup(site_hits[s].target_ac);
        printf("// \n");
        printf("Sequence: %s\n", this_target);
        printf("Sites:\n");
        while (s < n_site_hits && ! strcmp(site_hits[s].target_ac, this_target))
            output_site_hit(site_hits[s++], 1, 0);
    }

    free(this_target);
}


// Stitch together the domain and site results
void output_dom_sites_as_tab(struct hmmer_dom *dom_hits, int n_dom_hits, struct site_match *site_hits, int n_site_hits)
{
    int h = 0;
    int s = 0;
    int cmp;
    char *this_target;
    this_target = strdup("");

    // Sort both domains and sites by target/model so that the results can be interleaved
    // A 2-D array for hits might well have been better
    qsort(dom_hits, n_dom_hits, sizeof(struct hmmer_dom), cmp_dom_target_model);

    // Skip the matches without accessions - these were the ones filtered out earlier
    while (strlen(dom_hits[h].target_ac) == 0 && strlen(dom_hits[h].model_ac) == 0)
        h++;

    while (h < n_dom_hits) {
        output_dom_hit(dom_hits[h++], 1, 1);
    }
    while (s < n_site_hits) {
        output_site_hit(site_hits[s++], 1, 1);
    }

    free(this_target);
}


void identify_site_matches(char *aln_fn, struct family *families, int n_families, struct site_match **site_hits, int *n_site_hits, int *ali_present, struct no_hit **no_hits, int *n_no_hits)
{
    ESLX_MSAFILE *msaf;
    ESL_MSA *msa = NULL;
    struct feature *features = NULL;
    int rv;
    int nfam = 0;

    if (eslx_msafile_Open(NULL, aln_fn, NULL, eslMSAFILE_STOCKHOLM, NULL, &msaf) != eslOK) {
        fprintf(stderr, "ESL: Error opening %s\n", aln_fn);
        exit (1);
    }

    // Loop through alignments - for each one we need to read through the list of families
    // to get the next one which reported an alignment - important that the input files were from
    // the same search!
    while ((rv = eslx_msafile_Read(msaf, &msa)) != eslEOF) {
        while (ali_present[nfam] == 0) { // Skip to the next one which has an alignment
            nfam++;
        }
        if (rv != eslOK) {
            fprintf(stderr, "Error reading alignment from '%s'\n", aln_fn);
            exit(1);
        }
        if (families[nfam].n_features > 0) {
            get_site_matches(families[nfam], msa, site_hits, n_site_hits, no_hits, n_no_hits);
        }
        nfam++;
        esl_msa_Destroy(msa);
    }

    qsort(*site_hits, *n_site_hits, sizeof(struct site_match), cmp_site_target_model);
    qsort(*no_hits, *n_no_hits, sizeof(struct no_hit), cmp_nohit_target_model);
    eslx_msafile_Close(msaf);
}


// Get per residue matches using alignments for this family
void get_site_matches(struct family family, ESL_MSA *msa, struct site_match **site_hits, int *n_site_hits, struct no_hit **no_hits, int *n_no_hits)
{
    int *rf_array;
    int n_seq = msa->nseq;
    int alen = msa->alen;
    int **pos_map;
    int *seqs_matched = NULL;
    int f, s, spos, fpos, rpos, apos, fi;
    int next_fpos = 0;
    char seq_base;
    char *tmp;
    char *tmp2;
    struct seq_matches *matches = NULL; // array for temp results - one per sequence - reused for each feature

    if ((rf_array = (int *)malloc(sizeof(int) * alen)) == NULL) {
        fprintf(stderr, "Error - out of memory?\n");
        exit (1);
    }
    rf_to_array(msa, rf_array, alen);
    seqs_matched = (int *)malloc(n_seq * sizeof(int));

    // array to map alignment coords to sequence coords
    pos_map = (int **)malloc(n_seq * sizeof(int *));
    for (s = 0; s < n_seq; s++) {
        // seqs_matched[s] = family.n_features; // assume that a sequence matches all the features; it won't of course. this is decremented for each feature a sequence doesn't match. zero => no match to any feature
        seqs_matched[s] = 0; // assume that a sequence matches all the features; it won't of course. this is decremented for each feature a sequence doesn't match. zero => no match to any feature
        pos_map[s] = (int *)malloc(alen * sizeof(int));
        spos = get_start_from_nse(msa->sqname[s]);
        for (apos = 0; apos < alen; apos++) {
            if (isalpha(msa->aseq[s][apos]))
                pos_map[s][apos] = spos++;
            else
                pos_map[s][apos] = -1;
        }
    }

    // loop over features and columns within features and identify matching sequences
    for (f = 0; f < family.n_features; f++) {
        if ((matches = (struct seq_matches *)realloc(matches, n_seq * sizeof(struct seq_matches))) == NULL) {
            fprintf(stderr, "Error - out of memory?\n");
            exit (1);
        }
        for (s = 0; s < n_seq; s++) {
            matches[s].has_matched = 0;
            if ((matches[s].residue_matches = (char *)malloc(family.n_sites[f])) == NULL) {
                fprintf(stderr, "Error - out of memory?\n");
                exit (1);
            }
            matches[s].residue_match_coords = (int *)malloc(sizeof(int) * family.n_sites[f]);
            //matches[s].residue_matches[family.n_sites[f]] = '\0';
        }
        apos = 0;
        rpos = 0; // index of residues of interest within the pattern
        for (fi = 0; fi < family.n_sites[f]; fi++, next_fpos = 0) {
            fpos = family.site[f][fi];
            for (; apos < alen && ! next_fpos; apos++) {
                if (rf_array[apos] == fpos) {
                    for (s = 0; s < n_seq; s++) {
                        seq_base = msa->aseq[s][apos];
                        if (seq_base == family.residue[f][fi]) {
                            // store matched residue/coordinate
                            matches[s].residue_matches[rpos] = seq_base;
                            matches[s].residue_match_coords[rpos] = pos_map[s][apos];
                            matches[s].has_matched++;
                        }
                    }
                    next_fpos = 1; // break from inner loop over apos - jump to next feature position
                    rpos++;
                }
            }
        }
        for (s = 0; s < n_seq; s++) {
            tmp = (char *)malloc(1000);
            tmp2 = tmp;
            if (matches[s].has_matched == family.n_sites[f]) {
                seqs_matched[s]++;
                *site_hits = realloc(*site_hits, (1 + *n_site_hits) * sizeof(struct site_match));
                (*site_hits)[*n_site_hits].target_ac = strndup(msa->sqname[s], (rindex(msa->sqname[s], '/') - msa->sqname[s]));
                (*site_hits)[*n_site_hits].model_ac = strdup(family.name);
                (*site_hits)[*n_site_hits].match_desc = strdup(family.feature_name[f]);
                for (rpos = 0; rpos < family.n_sites[f]; rpos++) {
                    sprintf(tmp2, "%c%d,", matches[s].residue_matches[rpos], matches[s].residue_match_coords[rpos]);
                    tmp2 = tmp + strlen(tmp);
                }
                tmp[strlen(tmp) - 1] = '\0';
                (*site_hits)[*n_site_hits].match_str = strdup(tmp);
                ++*n_site_hits;
            }
            free(tmp);
            free(matches[s].residue_match_coords);
            free(matches[s].residue_matches);
        }
    }
    for (s = 0; s < n_seq; s++) {
        if (seqs_matched[s] == 0) {
            (*no_hits) = realloc(*no_hits, (1 + *n_no_hits) * sizeof(struct no_hit));
            (*no_hits)[*n_no_hits].target_ac = strdup(msa->sqname[s]);
            (*no_hits)[*n_no_hits].model_ac = strdup(family.name);
            ++*n_no_hits;
        }
    }
    free(matches);
    free(seqs_matched);

    for (s = 0; s < n_seq; s++)
        free(pos_map[s]);
    free(pos_map);
    free(rf_array);
}


// Parse aligment rf line
void rf_to_array(ESL_MSA *msa, int *rf_array, int alen)
{
    int i;
    int c = 0;

    for (i = 0; i < alen; i++) {
        if (msa->rf[i] == 'x')
            rf_array[i] = c++;
        else
            rf_array[i] = -1;
    }
}


void get_options_post(int argc, char **argv, int *only_matches, char **hmmer_path, char **hmmer_out, char **output, char **dom_file, char **alignments, char **site_info, char **format)
{
    static struct option long_options[] =
    {
        {"help",         no_argument,       0,  'h' },
        {"version",      no_argument,       0,  'v' },
        {"hmmerpath",    required_argument, 0,  'p' }, // path to hmm* binaries (overrides $HMMER_PATH)
        {"format",       required_argument, 0,  'f' }, // Not yet implemented - output text format
        {"dom",          required_argument, 0,  'd' }, // HMMER dom table (prefixed with $SFLD_OUTPUT if set)
        {"alignments",   required_argument, 0,  'a' }, // SFLD alignments (prefixed with $SFLD_OUTPUT if set)
        {"hmmer-out",    required_argument, 0,  'O' }, // SFLD alignments (prefixed with $SFLD_OUTPUT if set)
        {"site-info",    required_argument, 0,  's' }, // Sequence [target] database
        {"output",       required_argument, 0,  'o' }, // Output file (otherwise STDOUT)
        {0,              0,                 0,   0  }
    };
    int long_index = 0;
    int opt;
    char *path;

    while ((opt = getopt_long(argc, argv,"p:a:f:d:O:s:o:mhv",
                   long_options, &long_index )) != -1) {
        switch (opt) {
             case 'm' : *only_matches = 1;
                 break;
             case 'O' : *hmmer_out = strdup(optarg); 
                 break;
             case 'f' : *format = strdup(optarg); 
                 break;
             case 'o' : if ((path = getenv("SFLD_OUTPUT")) == NULL)
                            *output = strdup(optarg); 
                        else
                            path_concat(path, optarg, output);
                 break;
             case 'a' : if ((path = getenv("SFLD_OUTPUT")) == NULL)
                            *alignments = strdup(optarg); 
                        else
                            path_concat(path, optarg, alignments);
                 break;
             case 's' : if ((path = getenv("SFLD_OUTPUT")) == NULL)
                            *site_info = strdup(optarg); 
                        else
                            path_concat(path, optarg, site_info);
                 break;
             case 'd' : if ((path = getenv("SFLD_OUTPUT")) == NULL)
                            *dom_file = strdup(optarg); 
                        else
                            path_concat(path, optarg, dom_file);
                 break;
             case 'p' : *hmmer_path = strdup(optarg);
                 break;
             case 'h' : {
                        show_help(argv[0]);
                        exit(0);
             }
                 break;
             case 'v' : {
                        printf("%s\n", SFLD_POSTPROCESSOR_VERSION);
                        exit(0);
             }
                 break;
             default: {
                        fprintf(stderr, "Unrecognised option '%c'\n", optopt);
                        show_help(argv[0]);
                        exit(1);
             }
        }
    }
    if (*hmmer_path == NULL && ((path = getenv("HMMER_PATH")) != NULL))
        *hmmer_path = strdup(path);
}


int get_start_from_nse(char *s)
{
    int i;
    char *p;
    p = rindex(s, '/');
    if (i = atoi(p + 1))
        return i;
    else {
        fprintf(stderr, "Unable to parse name/start-end string '%s'", s);
        exit(1);
    }
}


int parse_hmmer_dom(struct hmmer_dom *pd, char *line)
{
    int p;
    char *c;
    char ac[1000];
    sscanf(line, "%s %*s %*s %*s %s %*s %n", ac, &pd->model_ac, &p);
    line += p;
    sscanf(line, "%f %f %f %*s %*s %n", &pd->seq_evalue, &pd->seq_score, &pd->seq_bias, &p);
    line += p;
    sscanf(line, "%f %f %f %f %n", &pd->dom_cevalue, &pd->dom_ievalue, &pd->dom_score, &pd->dom_bias, &p);
    line += p;
    sscanf(line, "%d %d %d %d %n", &pd->hmm_start, &pd->hmm_end, &pd->ali_start, &pd->ali_end, &p);
    line += p;
    sscanf(line, "%d %d %f", &pd->env_start, &pd->env_end, &pd->accuracy);
    sprintf(pd->target_ac, "%s/%d-%d", ac, pd->ali_start, pd->ali_end);
}


// Read domtblout file and store hits sorted by target and model accession
// Also store a list of family accessions with matches - will need to know which accessions are represented
// in the alignment file
void read_domtblout(char *fn, struct hmmer_dom **hits, int *n_hits)
{
    static FILE *fp;
    char *line = NULL;
    size_t r;

    int n_alloc = 0;
    *n_hits = 0;
    *hits = NULL;

    if ((fp = fopen(fn, "r")) == NULL) {
        fprintf(stderr, "Failed to open file '%s'\n", fn);
        exit(1);
    }
    do {
        getline(&line, &r, fp);
    } while (! feof(fp) && *line == '#');

    while (! feof(fp) && *line != '#') {
        if (*n_hits == n_alloc) {
            n_alloc += 100;
            *hits = (struct hmmer_dom *)realloc(*hits, n_alloc * sizeof(struct hmmer_dom));
        }
        parse_hmmer_dom(*hits + (*n_hits)++, line);
        getline(&line, &r, fp);
    }
    *hits = (struct hmmer_dom *)realloc(*hits, *n_hits * sizeof(struct hmmer_dom));

    qsort(*hits, *n_hits, sizeof(struct hmmer_dom), cmp_dom_target_model);

    // Skip to end to make sure the file is complete
    while (getline(&line, &r, fp) > 0)
        ;

    if (NULL == strstr(line, "[ok]")) {
        fprintf(stderr, "Failed to see see [ok] in file '%s': hmmsearch failed?\n", fn);
        exit(1);
    }

    free(line);
    fclose(fp);
}


void path_concat(char *p, char *f, char **n) {
    *n = (char *)malloc(strlen(p) + 2 + strlen(f));
    strcpy(*n, p);
    strcpy(*n + strlen(p), "/");
    strcpy(*n + strlen(p) + 1, f);
}


int cmp_nohit_target_model(const void *p1, const void *p2)
{
    struct no_hit *d1, *d2;
    int i;
    d1 = (struct no_hit *) p1;
    d2 = (struct no_hit *) p2;
    i = strcmp(d1->target_ac, d2->target_ac);
    if (i) return i;
    return strcmp(d1->model_ac, d2->model_ac);
}


int cmp_dom_target_model(const void *p1, const void *p2)
{
    struct hmmer_dom *d1, *d2;
    int i;
    d1 = (struct hmmer_dom *) p1;
    d2 = (struct hmmer_dom *) p2;
    i = strcmp(d1->target_ac, d2->target_ac);
    if (i) return i;
    return strcmp(d1->model_ac, d2->model_ac);
}


int cmp_site_target_model(const void *p1, const void *p2)
{
    struct site_match *d1, *d2;
    int i;
    d1 = (struct site_match *) p1;
    d2 = (struct site_match *) p2;
    i = strcmp(d1->target_ac, d2->target_ac);
    if (i) return i;
    return strcmp(d1->model_ac, d2->model_ac);
}


// utility comparison for the filter function - lists are sorted first by target then by model
int cmp_match_pair(char *target_1, char *target_2, char *model_1, char *model_2)
{
    int c1 = strcmp(target_1, target_2);
    int c2 = strcmp(model_1, model_2);
    // compare target strings
    if (c1 > 0)
        return 1;
    else if (c1 < 0)
        return -1;
    // targets same - compare model strings
    else
        return c2;
}


void show_help(char *progname)
{
   printf("Post-process results of HMMER search on SFLD HMMs\n");
   printf("Usage %s: options:\n", progname);
   printf("\t--nosearch    | -S         don't run search if output files exist\n");
   printf("\t--version     | -v         show program version\n");
   printf("\t--hmmerpath   | -p PATH    path to hmm* binaries (overrides $HMMER_PATH)\n");
   printf("\t--alignments  | -a         HMMER alignment file\n");
   printf("\t--dom         | -d         HMMER domtblout file\n");
   printf("\t--hmmer-out   | -O         HMMER output file\n");
   printf("\t--site-info   | -s         SFLD reside annotation file\n");
   printf("\t--format      | -f FORMAT  output text format [not implemented]\n");
   printf("\t--output      | -o FILE    output file (otherwise STDOUT)\n");
   printf("\n");
}


void read_site_data(char *fn, int *n_fam, struct family **families)
{
    FILE *fp;
    int s, f, nc;
    size_t n;
    char *line = NULL;
    char *l, *p;

    *families = NULL;
    int nf = 0;

    if ((fp = fopen(fn, "r")) == NULL) {
        fprintf(stderr, "Unable to open '%s'\n", fn);
        exit(1);
    }

    while (getline(&line, &n, fp) != -1)
    {
        if (*line == '#')
            continue;
        if (! strncmp(line, "ACC", 3)) {
            *families = (struct family *)realloc(*families, (nf + 1) * sizeof(struct family));
            (*families)[nf].name = (char *)malloc(SFLD_NAME_LEN + 3);
            sscanf(line + 4, "%s %d", (*families)[nf].name, &(*families)[nf].n_features);
            (*families)[nf].n_sites = (int *)malloc((*families)[nf].n_features * sizeof(int));
            (*families)[nf].feature_name = (char **)malloc((*families)[nf].n_features * sizeof(char *));
            (*families)[nf].site = (int **)malloc((*families)[nf].n_features * sizeof(int *));
            (*families)[nf].residue = (char **)malloc((*families)[nf].n_features * sizeof(int *));
            for (f = 0; f < (*families)[nf].n_features; f++) {
                if (getline(&line, &n, fp) == -1) {
                    fprintf(stderr, "line\n");
                    exit(1);
                }
                if (strncmp(line, "FEAT", 4)) {
                    fprintf(stderr, "feat\n");
                    exit(1);
                }
                p = line + 5;
                l = index(p, ' ');
                (*families)[nf].feature_name[f] = strndup(p, l - p);
                p = l + 1;
                sscanf(p, "%d %n", &(*families)[nf].n_sites[f], &nc);
                (*families)[nf].site[f] = (int *)malloc((*families)[nf].n_sites[f] * sizeof(int));
                (*families)[nf].residue[f] = (char *)malloc((*families)[nf].n_sites[f] * sizeof(int));
                p += nc;
                for (s = 0; s < (*families)[nf].n_sites[f]; s++) {
                    sscanf(p, "%c %d %n", &(*families)[nf].residue[f][s], &(*families)[nf].site[f][s], &nc);
                    p += nc;
                }
            }
            nf++;
        }
    }
    *n_fam = nf;
    fclose(fp);
    free(line);
}


void output_site_hit(struct site_match hit, int w_model, int w_target)
{
    if (w_model)
        printf("%s\t", hit.model_ac);
    if (w_target)
        printf("%s\t", hit.target_ac);
    printf("%s\t%s\n", hit.match_str, hit.match_desc);
}


void output_dom_hit(struct hmmer_dom hit, int w_model, int w_target)
{
    //model_ac, seq_evalue, seq_score, seq_bias, hmm_start, hmm_end, dom_score, ali_start, ali_end, env_start, env_end, dom_cevalue, dom_ievalue, accuracy, dom_bias

    if (w_model)
        printf("%s\t", hit.model_ac);
    printf("%.3e\t%.3e\t%.3f\t", hit.seq_evalue, hit.seq_score, hit.seq_bias);
    printf("%d\t%d\t%.3f\t", hit.hmm_start, hit.hmm_end, hit.dom_score);
    printf("%d\t%d\t%d\t%d\t", hit.ali_start, hit.ali_end, hit.env_start, hit.env_end);
    printf("%.3e\t%.3e\t%.3f\t%.3f", hit.dom_cevalue, hit.dom_ievalue, hit.accuracy, hit.dom_bias);
    if (w_target)
        printf("\t%s", hit.target_ac);
    printf("\n");
}


// go through the list of dom hits and remove those (set ac to "") for any which are blacklisted for having no site matches
// both the domain hit list and blacklist are in the same order
void filter_no_hits(struct hmmer_dom *dom_hits, int n_dom_hits, struct no_hit *no_hits, int n_no_hits)
{
    int h;
    int n = 0;
    for (h = 0; h < n_dom_hits; h++) {
        // If the first hit in the blacklist is below the first in the domain list (cmp_match_pair() returns > 1) we won't ever match it with the domains: skip to the next one in the blacklist
        while (n < n_no_hits && cmp_match_pair(dom_hits[h].target_ac, no_hits[n].target_ac, dom_hits[h].model_ac, no_hits[n].model_ac) > 0)
            n++;
        if (n == n_no_hits)
            return;
        // match - set the accessions to ""
        if (! strcmp(dom_hits[h].target_ac, no_hits[n].target_ac) && ! strcmp(dom_hits[h].model_ac, no_hits[n].model_ac)) {
            dom_hits[h].target_ac[0] = '\0';
            dom_hits[h].model_ac[0] = '\0';
        }
    }
}


void strip_dom_se(struct hmmer_dom *dom_hits, int n_dom_hits)
{
    int h;
    char *p;
    for (h = 0; h < n_dom_hits; h++) {
        if (strlen(dom_hits[h].target_ac) > 0 && strlen(dom_hits[h].target_ac) > 0) {
            p = rindex(dom_hits[h].target_ac, '/');
            *p = '\0';
        }
    }
}


// Read through main hmmer output file and build a list of which HMMs have alignments
void retrieve_families_with_ali(char *fn, int **ali_present, int *nfam)
{
    size_t line_len;
    char *line = NULL;
    FILE *fp;

    if ((fp = fopen(fn, "r")) == NULL) {
        fprintf(stderr, "Unable to open HMMER output '%s'\n", fn);
        exit(1);
    }

    *ali_present = NULL;

    getline(&line, &line_len, fp);
    if (strncmp(line, "# hmmsearch", 11)) { // FIXME - check this
        fprintf(stderr, "This does not look like a hmmer output file; expecting \"# hmmsearch\"\n");
        exit(1);
    }

    while ((getline(&line, &line_len, fp)) != -1) {
        if (! strncmp(line, "Accession:", 10)) {
            ++*nfam;
            *ali_present = (int *)realloc(*ali_present, *nfam * sizeof(int));
            // Assume this family has an alignment ...
            (*ali_present)[*nfam - 1] = 1;
        }
        else if (! strncmp(line, "# No hits satisfy inclusion thresholds; no alignment saved", 58)) {
            // ... unless it's reported that it doesn't
            (*ali_present)[*nfam - 1] = 0;
        }
    }

    if (strncmp(line, "[ok]", 4)) {
        fprintf(stderr, "Failed to see see [ok] in file '%s': hmmsearch failed?\n", fn);
    }
    free(line);
    fclose(fp);
}


void free_no_hits(int n, struct no_hit *nh)
{
    int i;
    for (i = 0; i < n; i++) {
        free(nh[i].target_ac);
        free(nh[i].model_ac);
    }
    free(nh);
}


void free_site_hits(int n, struct site_match *hits)
{
    int i;
    for (i = 0; i < n; i++) {
        free(hits[i].target_ac);
        free(hits[i].model_ac);
        free(hits[i].match_str);
        free(hits[i].match_desc);
    }
    free(hits);
}


void clear_family_data(int n, struct family *fams)
{
    int i, j;

    for (i = 0; i < n; i++) {
        free(fams[i].name);
        for (j = 0; j < fams[i].n_features; j++) {
            free(fams[i].site[j]);
            free(fams[i].residue[j]);
            free(fams[i].feature_name[j]);
        }
        free(fams[i].site);
        free(fams[i].n_sites);
        free(fams[i].feature_name);
        free(fams[i].residue);
    }
    free(fams);
}
