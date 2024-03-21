features = read_tsv('~/Github/published/RaczBecknerHayPierrehumbert2019/models/mgl/baseline_mgl/CELEXFull3.fea')

features %<>% 
  slice(-1) %>% 
  select(-1) %>% 
  rename()

pasteIntoString = function(df1){
  paste(paste(df1[1, ], names(df1), sep = " "), collapse = ", ")  
}

prules = rules %>% 
  distinct(rule_id,Pfeat) %>% 
  mutate(Pfeat = str_replace_all(Pfeat, '[\\[\\]]', '')) %>% 
  separate_rows(Pfeat, sep = ', ') %>% 
  nest(data = Pfeat) %>% 
  mutate(
    natural_class = map(data, ~ 
                          left_join(., features, by = join_by('Pfeat' == 'Seg.')) %>% 
                          select_if(~all(. == .[1])) %>% 
                          distinct() %>% 
                          pasteIntoString()
                          )
  )

prules$natural_class[[1]]
