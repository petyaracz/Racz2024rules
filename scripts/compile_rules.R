# create tidy rules, match to forms

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
r = read_tsv(glue('{path}/models/mgl/baseline_mgl/CELEXFull3.sum'))
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

# rules
rules = r %>% 
  mutate(
    present = str_replace(form1, '»', ''),
    past = str_replace(form2, '»', ''),
    rule = case_when(
     is.na(Qfeat) & !is.na(Q) ~ glue('{A} -> {B} \ {Pfeat}{P} _ {Q}'),
     !is.na(Qfeat) & is.na(Q) ~ glue('{A} -> {B} \ {Pfeat}{P} _ {Qfeat}'),
     is.na(Qfeat) & is.na(Q) ~ glue('{A} -> {B} \ {Pfeat}{P} _ ')
    ) %>% 
      str_replace_all('NA', '')
  ) %>% 
  select(rule,past,present,A,B,Change,P,Pfeat,Q,Qfeat,scope,hits,reliability,confidence,`related forms`,exceptions)

# add rule id
rules = rules %>% 
  distinct(rule,scope,hits) %>% 
  mutate(rule_id = glue('rule {1:n()}')) %>% 
  left_join(rules)

# add features

# nice rules
celex2 = celex %>% 
  rename(ahpa = X1, orth = X4) %>% 
  distinct(ahpa, orth)

# duplicates because of orthography: raise raze and so on.
rules_forms = rules %>% 
  distinct(rule,rule_id,Change,P,Pfeat,Q,Qfeat,scope,hits,confidence,`related forms`,exceptions) %>% 
  mutate(
    related_forms_list = str_split(`related forms`, ','),
    exceptions_list = str_split(exceptions, ', '),
  ) %>% 
  unnest(related_forms_list) %>%
  mutate(ahpa = str_replace_all(related_forms_list, c(' ' = '', '»' = ''))) %>% 
  left_join(celex2) %>% 
  group_by(rule,Change,P,Pfeat,Q,Qfeat,scope,hits,confidence) %>% 
  mutate(related_forms = paste(orth, collapse = ', ')) %>% 
  distinct(rule,rule_id,Change,P,Pfeat,Q,Qfeat,scope,hits,confidence,exceptions_list,related_forms) %>% 
  ungroup() %>% 
  unnest(exceptions_list) %>%
  mutate(ahpa = str_replace_all(exceptions_list, c(' ' = '', '»' = ''))) %>% 
  left_join(celex2) %>% 
  group_by(rule,rule_id,Change,P,Pfeat,Q,Qfeat,scope,hits,confidence,related_forms) %>% 
  mutate(exceptions = paste(orth, collapse = ', ')) %>% 
  distinct(rule,rule_id,Change,P,Pfeat,Q,Qfeat,scope,hits,confidence,related_forms,exceptions) %>% 
  ungroup()

# combine rules with nice related form and exception list
rules2 = rules %>% 
  select(-`related forms`,-exceptions) %>% 
  left_join(rules_forms)

# so some rules are there twice, once B==t, once B==d. otherwise completely identical. so we can keep the d ones and drop the t ones. this makes no practical difference.
rules_filt = rules2 %>% 
  distinct(rule, rule_id, A, B, scope, hits, confidence, related_forms, exceptions) %>% 
  group_by(scope, hits, confidence, related_forms, exceptions) %>% 
  arrange(B) %>% 
  slice(1) %>% 
  ungroup()

rules3 = rules2 %>% 
  inner_join(rules_filt)

# looks about right
# anti_join(rules2,rules3) %>% View

# combine rules and forms
rforms = left_join(forms,rules3)

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
  select(participant_id,word,regular_form,irregular_form,disc,category,baseline_log_odds_regular,weight,regular,irregular,resp_reg,reg_rate,lex_typicality,phase,overall_index,trial_index,resp_bot_reg,esp_match,rule,rule_id,best_rule_word_type,type,scope,hits,reliability,confidence)
  
# -- write -- #

write_tsv(d3, 'dat/exp_data_with_rules.gz')
