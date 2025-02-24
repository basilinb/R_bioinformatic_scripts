"Hypergeometric enrichment of genes in Broad gene sets

#################

Kim Dill-Mcfarland
University of Washington, kadm@uw.edu
Copyright (C) 2021 Kim Dill-Mcfarland
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

Input parameters:
REQUIRED
ONE OF
  gene.list = List of named vectors as in data.ls['group 1'] = c('gene1','gene2',...) where
              enrichment is assessed separately for each group
  gene.df = data frame with groups in one column and gene IDs in another. Gene IDs must be in geneName
      df.group = Column name in gene.df containing groups to enrich within. Default is 'group'

AND
  category = Character name of Broad gene set to enrich in. One of 'H' or 'C1' through 'C8'
      subcategory = If using a subset of the above gene set. One of
                    'CP' - C2 canonical pathways including BIOCARTA, KEGG, PID, REACTOME
                    'GO' - C5 gene ontology including molecular function (MF), biological process (BP),
                           cellular component (CC)
                    or
                    Colon separated combination of the above with further subsetting as in 
                    'CP:KEGG' or 'GO:BP'
  
  ID.type = Character identifier type for genes in data. One of 'ENTREZ' or 'ENSEBML' or 'SYMBOL'
  genome = Character for genome reference to use. One of 'org.Hs.eg.db', 'org.Mm.eg.db' currently allowed

OPTIONAL
  basename = Character prefix for output file name
  outdir = File path to directory where output is saved. Default is 'results/enrichment/'
   
Example
  enrich.fxn(gene.df=data.df,
             df.group='module',
             category='C5', subcategory='GO',
             ID.type='ENTREZ',
             genome='org.Hs.eg.db', 
             basename='modules', 
             outdir='results/enrichment/')
"

##### Loop function #####
enrich.fxn <- function(gene.list=NULL,
                       gene.df=NULL, df.group="group",
                       category, subcategory=NULL,
                       ID.type=NULL,
                       genome, 
                       basename=NULL, outdir="results/enrichment/"){
  
##### Setup #####
  require(clusterProfiler)
  require(msigdbr)
  require(tidyverse)
  require(plyr)
  if(genome== "org.Hs.eg.db"){
    require(org.Hs.eg.db)}
  if(genome== "org.Mm.eg.db"){
    require(org.Mm.eg.db)}
  
  #Silence warnings
  options(warn=-1)

  #Blank holders
  results <- list()
  
##### Loop through gene df #####
  if(!is.null(gene.df)){
    #List all possible group levels
    group.list <- unique(gene.df[,df.group])
    
    for(group.level in group.list){
      print(group.level)
      #Get gene list for each group level
      to.enrich <- gene.df %>% 
        filter(get(df.group) == group.level) %>% 
        dplyr::select(geneName) %>% unlist(use.names = FALSE)
      #Run enrich and save to results list
      results[[group.level]] <- run.enrich(to.enrich = to.enrich, 
                                         group.level = group.level,
                                         genome=genome, 
                                         category=category,
                                         subcategory=subcategory,
                                         ID.type=ID.type)
    }
    
##### Loop through gene lists #####
  } else if(!is.null(gene.list)){
    for(group.level in names(gene.list)){
      print(group.level)
      #Get gene list for each group level
        to.enrich <- gene.list[[group.level]]
        
        #Run enrich and save to results list 
        results[[group.level]] <- run.enrich(to.enrich = to.enrich, 
                                           group.level = group.level,
                                           genome=genome, 
                                           category=category,
                                           subcategory=subcategory,
                                           ID.type=ID.type)
    }
##### Stop if no genes provided #####
  } else{
    stop("Please provide gene list or data frame.")
  }
  
##### Save results #####
  dir.create(outdir, showWarnings = FALSE)
  
  #combine list of df results
  results.all <- plyr::ldply (results, data.frame) %>% 
    dplyr::select(-'.id')
  
  #Make filename
  if(is.null(basename) & is.null(subcategory)){ 
    output.name <- category 
    filename <- paste(outdir,"enrich_",output.name, ".csv", sep="")
  } else if(is.null(basename) & !is.null(subcategory)){
    output.name <- paste(category, gsub(":", ".", subcategory), sep="_")
    filename <- paste(outdir,"enrich_",output.name, ".csv", sep="")
  } else if(!is.null(basename) & is.null(subcategory)){
    output.name <- paste(basename, category, sep="_") 
    filename <- paste(outdir,"enrich_",
                      output.name, ".csv", sep="")
  } else{ 
    output.name <- paste(basename, category, gsub(":", ".", subcategory),
                         sep="_") 
    filename <- paste(outdir, "enrich_",
                      output.name, ".csv", sep="")
  }
  
  #Save
  write_csv(results.all, filename)
  
}

##### enrich function #####
run.enrich <- function(to.enrich, group.level, 
                     genome, category, subcategory, ID.type, ...){
  
  #Convert ENSEMBL IDs if needed
  if(ID.type == "ENSEMBL"){
    #Convert gene list to Entrez ID
    gene.entrez <- clusterProfiler::bitr(to.enrich, fromType="ENSEMBL",
                                         toType=c("ENTREZID","SYMBOL"),
                                         OrgDb=genome)
    
    gene.entrez.list <- gene.entrez$ENTREZID
  } else if(ID.type =="ENTREZ"){
    gene.entrez <- clusterProfiler::bitr(to.enrich, fromType="ENTREZID",
                                         toType=c("ENSEMBL","SYMBOL"),
                                         OrgDb=genome)
    gene.entrez.list <- to.enrich
  } else if(ID.type == "SYMBOL"){
    #Convert gene list to Entrez ID
    gene.entrez <- clusterProfiler::bitr(to.enrich, fromType="SYMBOL",
                                         toType=c("ENTREZID", "ENSEMBL"),
                                         OrgDb=genome)
    
    gene.entrez.list <- gene.entrez$ENTREZID
  }else{
    stop("Function only allows HGNC symbols, ENSEMBL or ENTREZ IDs")
  }
  

  #Get database of interest
  if(genome == "org.Hs.eg.db"){
    
    #No subcategory
    if(is.null(subcategory)){
      db.species <- as.data.frame(msigdbr(species = "Homo sapiens", 
                                          category = category))
    } else
    # Combine all CP subs
    if(subcategory == "CP"){
      db.species <- as.data.frame(msigdbr(species = "Homo sapiens", 
                                          category = "C2",
                                          subcategory = "CP:BIOCARTA")) %>% 
        bind_rows(as.data.frame(msigdbr(species = "Homo sapiens", 
                                        category = "C2",
                                        subcategory = "CP:KEGG"))) %>% 
        bind_rows(as.data.frame(msigdbr(species = "Homo sapiens", 
                                        category = "C2",
                                        subcategory = "CP:PID"))) %>% 
        bind_rows(as.data.frame(msigdbr(species = "Homo sapiens", 
                                        category = "C2",
                                        subcategory = "CP:REACTOME")))
    } else if(subcategory == "CP:BIOCARTA"){
      db.species <- as.data.frame(msigdbr(species = "Homo sapiens", 
                                          category = "C2",
                                          subcategory = "CP:BIOCARTA"))
    } else if(subcategory == "CP:KEGG"){
      db.species <- as.data.frame(msigdbr(species = "Homo sapiens", 
                                          category = "C2",
                                          subcategory = "CP:KEGG"))
    } else if(subcategory == "CP:PID"){
      db.species <- as.data.frame(msigdbr(species = "Homo sapiens", 
                                          category = "C2",
                                          subcategory = "CP:PID"))
    } else if(subcategory == "CP:REACTOME"){
      db.species <- as.data.frame(msigdbr(species = "Homo sapiens", 
                                          category = "C2",
                                          subcategory = "CP:REACTOME"))
    } else
      # Combine all GO subs
      if(subcategory == "GO"){
        db.species <- as.data.frame(msigdbr(species = "Homo sapiens", 
                                            category = "C5",
                                            subcategory = "GO:MF")) %>% 
          bind_rows(as.data.frame(msigdbr(species = "Homo sapiens", 
                                          category = "C5",
                                          subcategory = "GO:BP"))) %>% 
          bind_rows(as.data.frame(msigdbr(species = "Homo sapiens", 
                                          category = "C5",
                                          subcategory = "GO:CC")))
      } else if(subcategory=="GO:MF"){
        db.species <- as.data.frame(msigdbr(species = "Homo sapiens", 
                                            category = "C5",
                                            subcategory = "GO:MF"))
    } else if(subcategory=="GO:BP"){
      db.species <- as.data.frame(msigdbr(species = "Homo sapiens", 
                                          category = "C5",
                                          subcategory = "GO:BP"))
    } else if(subcategory=="GO:CC"){
      db.species <- as.data.frame(msigdbr(species = "Homo sapiens", 
                                          category = "C5",
                                          subcategory = "GO:CC")) %>% 
        bind_rows(as.data.frame(msigdbr(species = "Homo sapiens", 
                                        category = "C5",
                                        subcategory = "GO:BP"))) %>% 
        bind_rows(as.data.frame(msigdbr(species = "Homo sapiens", 
                                        category = "C5",
                                        subcategory = "GO:CC")))
    } else {
      db.species <- as.data.frame(msigdbr(species = "Homo sapiens", 
                                          category = category,
                                          subcategory = subcategory))}
    
  } else if(genome$packageName == "org.Mm.eg.db"){
    
    if(is.null(subcategory)){
      db.species <- as.data.frame(msigdbr(species = "Mus musculus",
                                          category = category)) 
    } else{
      db.species <- as.data.frame(msigdbr(species = "Mus musculus",
                                          category = category,
                                          subcategory = subcategory)) 
    }
  } else{
    stop("Function only available for human and mouse genomes.")
  }
  
  #run enrichment on gene list
  enrich <- enricher(gene=gene.entrez.list, 
                     TERM2GENE=dplyr::select(db.species, gs_name,
                                             entrez_gene))
  
  if (is.null(enrich)){
    enrich.result.clean <- data.frame(
      Description="No enriched terms",
      category=category, 
      group=group.level)
    if (!is.null(subcategory)){
      enrich.result.clean <- enrich.result.clean %>% 
        mutate(subcategory=subcategory)
    }
    
   return(enrich.result.clean)
    
  }
  else{
    #Extract results
    enrich.result <- enrich@result %>% 
      remove_rownames() %>% 
      arrange(p.adjust, Count)
    
    #Create group names for entrez+number genes ID'ed
    ## Use to separate list of entrez IDs if > 1 exist for a given term
    pivot_names <- c()
    for (i in 1:max(enrich.result$Count)){
      pivot_names[[i]] <- paste("entrez", i, sep="")
    }
    
    #Format category labels
    db.species.clean <- db.species %>% 
      dplyr::select(gs_cat, gs_subcat, gs_name) %>% 
      dplyr::rename(category=gs_cat, subcategory=gs_subcat, 
                    Description=gs_name) %>% 
      distinct()
    #Format results   
    enrich.result.clean <- enrich.result %>% 
      #Separate entrez ID lists
      separate(geneID, into=as.character(pivot_names), sep="/") %>% 
      pivot_longer(all_of(as.character(pivot_names)), names_to = "rep", 
                   values_to = "ENTREZID") %>% 
      drop_na(ENTREZID) %>% 
      #Match entrez IDs to gene IDs
      left_join(gene.entrez, by="ENTREZID") %>% 
      
      #Combine lists into single columns, sep by /
      group_by_at(vars(ID:Count)) %>% 
      dplyr::summarize(ENTREZIDs = paste(ENTREZID, collapse="/"),
             SYMBOLs = paste(SYMBOL, collapse="/"),
             ENSEMBLIDs = paste(ENSEMBL, collapse="/"),
             .groups="drop") %>% 
      #Extract values from ratios
      separate(BgRatio, into=c("size.term","size.category"), sep="/") %>% 
      separate(GeneRatio, into=c("size.overlap.term",
                                 "size.overlap.category"),
               sep="/") %>% 
      mutate_at(vars("size.term","size.category",
                     "size.overlap.term","size.overlap.category"),
                as.numeric) %>% 
      #Calculate k/K
      mutate("k/K"=size.overlap.term/size.term) %>% 
      
      #Add ID columns for database names
      left_join(db.species.clean, by = "Description") %>% 
      #Add columns for group info
      mutate(group=group.level, size.group = length(to.enrich)) %>% 
      #Reorder variables
      dplyr::select(category, subcategory,
                    group, size.group, 
                    size.overlap.category, size.category,
                    Description, size.overlap.term, size.term, `k/K`,
                    p.adjust, qvalue, ENTREZIDs:ENSEMBLIDs) %>% 
      arrange(p.adjust)  
    
    return(enrich.result.clean)
  }
}

