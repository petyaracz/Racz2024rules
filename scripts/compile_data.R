# combine rules, forms, experiment data

setwd('~/Github/Racz2024rules')

library(tidyverse)
library(magrittr)
library(glue)

# change this to wherever you cloned the 2019 repo:
path = '~/Github/published/RaczBecknerHayPierrehumbert2019/'

# -- read -- #

# baseline data
baseline = read_csv(glue('{path}/data/convergence_paper_baseline_data.txt'))
# rules
r = read_tsv('dat/rules_fancy.tsv')
# matcher
matcher = read_csv(glue('{path}/data/256verbs_print_forms.txt'))
# real verbs
celex = read_tsv(glue('{path}/models/mgl/baseline_mgl/CELEXFull3in.tsv'), col_names = F)
# esp data
d = read_csv(glue('{path}/data/convergence_paper_esp_data.txt'))
# test2 data to see who we kept
t2 = read_csv(glue('{path}/data/convergence_paper_esp_test2_predictions.txt'))

# -- main -- #

# who's in t2
parts = t2 %>% 
  distinct(participant_id) %>% 
  pull()

# same amount of people in d. this is already-filtered dataset.

d %>% 
  filter(participant_id %in% parts)

# counts
b_counts = baseline %>% 
  count(word,disc,regular) %>% 
  pivot_wider(names_from = regular, values_from = n) %>% 
  mutate(
    baseline_log_odds_regular = log(`TRUE` / `FALSE`),
    present = str_replace_all(disc, c('5' = 'o', 'Id' = '@d'))
    ) %>% 
  select(-`TRUE`,-`FALSE`)

# transcriptions
transcriptions = matcher %>% 
  select(
    base.form,
    regular.form,
    irregular.form,
    category
  ) %>% 
  pivot_longer(c(regular.form,irregular.form), names_to = 'type', values_to = 'past') %>% 
  mutate(
    disc = base.form,
    type = str_replace(type, '\\.form$', ''),
    present = str_replace_all(disc, c('5' = 'o', 'Id' = '@d')),
    past = str_replace_all(past, c('5' = 'o', 'Id' = '@d'))
  ) %>% 
  select(-base.form)

# baseline with proper transcriptions
forms = left_join(b_counts,transcriptions)  

# combine rules and forms
rforms = left_join(forms,r)

# mark best regular and irregular rule for each form
rforms %<>% 
  group_by(word,type) %>% 
  mutate(
    max_confidence = max(confidence),
    best_rule_word_type = confidence == max_confidence
  ) %>% 
  ungroup()

# combine rforms and exp data
intersect(names(rforms),names(d))
d2 = rforms %>% 
  select(-disc,-category,-max_confidence) %>% 
  right_join(d) %>% 
  arrange(participant_id,overall_index)

# tidy b weights
weights = rforms %>% 
  filter(best_rule_word_type) %>%
  select(word,disc,category,type,confidence,baseline_log_odds_regular) %>% 
  pivot_wider(names_from = type, values_from = confidence, values_fill = 0) %>% 
  mutate(weight = case_when(
    irregular == 0 ~ 1,
    irregular != 0 ~ regular / ( regular + irregular)
    )
  ) %>% 
  select(word,disc,baseline_log_odds_regular,weight,regular,irregular)

# add word past forms
d2 = matcher %>% 
  select(base.print,regular.print,irregular.print) %>% 
  rename(word = base.print, regular_form = regular.print, irregular_form = irregular.print) %>% 
  right_join(d2)
  
# tidy d
d3 = d2 %>% 
  mutate(
    resp_reg = case_when(
      phase == 'test1' ~ as.double(resp_pre_reg),
      phase == 'esp' ~ as.double(resp_esp_reg),
      phase == 'test2' ~ as.double(resp_post_reg)
    ),
    esp_match = resp_reg == resp_bot_reg
  ) %>% 
  left_join(weights) %>% 
  select(participant_id,word,regular_form,irregular_form,disc,category,baseline_log_odds_regular,weight,regular,irregular,resp_reg,reg_rate,lex_typicality,phase,overall_index,trial_index,resp_bot_reg,esp_match,rule,rule_tidy,rule_id,best_rule_word_type,type,scope,hits,reliability,confidence,related_forms,exceptions)
  
# -- write -- #

write_tsv(d3, 'dat/exp_data_with_rules.gz')
