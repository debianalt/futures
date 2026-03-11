# Sociotechnical Futures and Material Realities — Replication Materials

Data and code for the research project *Sociotechnical futures and material realities: technology, dematerialisation, and the politics of evidence*.

## Repository structure

```
├── data/
│   ├── works.csv              # 4,468 papers from OpenAlex (title, year, journal, citations, abstract)
│   ├── authorships.csv        # Author–institution–country links
│   ├── citation_edges.csv     # Intra-database citation network
│   ├── work_keywords.csv      # Author keywords
│   ├── work_topics.csv        # OpenAlex topic classifications
│   ├── search_provenance.csv  # Which query found each work
│   └── shortlist.csv          # Top 150 ranked candidates (output of 01_study_selection.R)
├── docs/
│   └── search_protocol.md     # Systematic search documentation (queries, databases, deduplication)
├── R/
│   ├── 01_study_selection.R   # Scoring pipeline → shortlist (§2 of the article)
│   ├── 02_field_mapping.R     # Epistemic geography, disciplines, trends (§3)
│   └── 03_figure.R            # Fig. 1: competing sociotechnical futures
├── sql/
│   ├── schema.sql             # PostgreSQL schema (alternative to CSV)
│   └── queries.sql            # Analytical queries
├── figures/
│   ├── fig01_competing_futures.png
│   └── fig01_competing_futures.pdf
├── LICENSE                    # MIT
└── README.md
```

## Requirements

R ≥ 4.1 with the following packages:

```r
install.packages(c("readr", "dplyr", "stringr", "tidyr", "forcats", "ggplot2", "here"))
```

## Reproducing the analysis

From the repository root:

```bash
# 1. Score and rank the literature database → data/shortlist.csv
Rscript R/01_study_selection.R

# 2. Map the field quantitatively (console output)
Rscript R/02_field_mapping.R

# 3. Generate Fig. 1
Rscript R/03_figure.R
```

## Data sources

- **Literature database**: Built from the [OpenAlex](https://openalex.org/) API via structured queries and citation snowballing from 9 seed papers. See `docs/search_protocol.md` for the full search strategy.
- **Figure 1**: Schematic diagram (no external data required).

## Citation

If you use these materials, please cite the article:

```bibtex
@article{gomez2026sociotechnical,
  author  = {G{\'o}mez, Raimundo El{\'i}as},
  title   = {Sociotechnical futures and material realities: technology,
             dematerialisation, and the politics of evidence},
  year    = {2026}
}
```

## License

MIT — see [LICENSE](LICENSE).
