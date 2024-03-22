# -- head -- #

setwd('~/Github/Racz2024rules/')

library(tidyverse)
library(magrittr)
library(glue)

# -- fun -- #

updateConfidence = function(learning_rate,which_rules){
  
  # take d, keep the reversed esp phase, only the best rules (those play into the final weight), tally up _participant_ responses
  updated_confidences = d %>%
    filter(
      phase == 'esp',
      reg_dist == 'reversed',
      best_rule_word_type
    ) %>% 
    mutate(resp_bot_reg = as.double(resp_bot_reg)) %>% 
    count(participant_id,rule,type,confidence,scope,resp_reg) %>%
    pivot_wider(names_from = resp_reg, values_from = n, values_fill = 0) %>% 
    rename(reg = `1`, irreg = `0`) %>% 
    # for each rule, update rule confidence for correct and incorrect rule predictions, depending on whether we're updating that type of rule in this run
    mutate(
      updated_confidence = case_when(
        which_rules == 'both' & type == 'regular' ~ confidence + reg * learning_rate,
        which_rules == 'both' & type == 'irregular' ~ confidence + irreg * learning_rate,
        which_rules == 'regular' & type == 'regular' ~ confidence + reg * learning_rate,
        which_rules == 'regular' & type == 'irregular' ~ confidence,
        which_rules == 'irregular' & type == 'regular' ~ confidence,
        which_rules == 'irregular' & type == 'irregular' ~ confidence + irreg * learning_rate
      )
    ) %>% 
    # return participant, rule, orig conf, updated conf
    select(participant_id,rule,confidence,updated_confidence)
  
  # grab the posttest, only the best rules, join updated confidences across rules
  final_confidences = d %>%
    filter(
      phase == 'posttest',
      reg_dist == 'reversed',
      best_rule_word_type
    ) %>% 
    select(participant_id,word,rule,type,confidence) %>%
    left_join(updated_confidences, by = join_by(participant_id, rule, confidence)) %>% 
    # if the rule wasn't in the esp its confidence didn't change
    mutate(
      final_confidence = case_when(
        is.na(updated_confidence) ~ confidence,
        !is.na(updated_confidence) ~ updated_confidence
      )
    ) %>% 
    # for each participant and word, we have two final confidences: from best regular and best irregular rule. this confidence either changed in the esp phase or it didn't because the rule wasn't called in the esp.
    select(participant_id,word,type,final_confidence)
  
  # we calc weights based on final confidences
  final_weights = final_confidences %>%
    pivot_wider(names_from = type, values_from = final_confidence, values_fill = 0) %>% 
    mutate(updated_weight = case_when(
      irregular == 0 ~ 1,
      irregular != 0 ~ regular / (regular + irregular)
    )
    ) %>% 
    select(-regular,-irregular)
  
  # we grab the posttest again and add weights
  reversed_posttest = d %>%
    filter(
      phase == 'posttest',
      reg_dist == 'reversed'
    ) %>% 
    select(participant_id,word,weight,resp_reg) %>% 
    left_join(final_weights, by = join_by(participant_id, word))
  
  # we calculate a summary for words in the entire reversed posttest
  reversed_summary = reversed_posttest %>% 
    group_by(word,weight) %>% 
    summarise(
      updated_weight = mean(updated_weight),
      mean_reg = mean(resp_reg)
    )
  
  # we return this summary
  return(reversed_summary)
}

# -- read -- #

d = read_tsv('dat/exp_data_with_rules.gz')

# -- wrangle -- #

# sort out factor levels
d %<>%
  mutate(
    phase = str_replace_all(phase, c('test1' = 'pretest', 'test2' = 'posttest')),
    phase = factor(phase, levels = c('pretest', 'esp', 'posttest')),
    reg_rate = factor(reg_rate, levels = c('-40%', 'nc', '+40%')),
    reg_dist = str_replace(lex_typicality, 'atypical', 'reversed'),
    reg_dist = factor(reg_dist, levels = c('reversed', 'random', 'typical')),
    type = factor(type, levels = c('regular', 'irregular'))
  )

# -- main -- #

# parameters: learning rate, which rules to use
parameters = crossing(
  learning_rate = seq(.05,1.5,.05),
  which_rules = c('both','regular','irregular')
)

# iterate the learner through the parameter settings
outcomes = parameters %>%
  rowwise() %>% 
  mutate(
    summary = list(updateConfidence(learning_rate, which_rules))
  )

# unnest it
outcomes_unnested = outcomes %>% 
  unnest(summary)

# get ten best outcomes (maybe one day I'll use this)
best_outcomes = outcomes_unnested %>% 
  group_by(learning_rate,which_rules) %>% 
  summarise(
    cor_weight = cor(mean_reg,updated_weight)
  ) %>% 
  arrange(-cor_weight) %>% 
  ungroup() %>% 
  slice(1:10)

# get bestest outcome
best_outcome = best_outcomes %>% 
  slice(1)

# get bestest values
best_outcome = outcomes_unnested %>% 
  inner_join(best_outcome)

# -- write -- #

write_tsv(outcomes_unnested, 'dat/modelling_outcomes.tsv')
write_tsv(best_outcome, 'dat/modelling_best_outcome.tsv')
