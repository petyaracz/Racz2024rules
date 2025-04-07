# script logic: 
# - compile data
# - learner
# fit learner on data with various parameter settings, get best settings, get all settings, write to file

# -- head -- #

setwd('~/Github/Racz2024rules/')

library(tidyverse)
library(magrittr)
library(glue)

# -- fun -- #

updateConfidence = function(learning_rate,which_rules,which_responses){
  
  # take d, keep the reversed esp phase, only the best rules (those play into the final weight), tally up robot / participant responses
  updated_confidences = d |>
    filter(
      phase == 'esp',
      reg_dist == 'reversed',
      best_rule_word_type
    ) |> 
    mutate(
      mod_resp_reg = case_when(
        which_responses == 'coplayer' ~ as.double(resp_bot_reg),
        which_responses == 'own' ~ resp_reg
      )
           ) |> 
    count(participant_id,rule,type,confidence,scope,mod_resp_reg) |>
    pivot_wider(names_from = mod_resp_reg, values_from = n, values_fill = 0) |> 
    rename(reg = `1`, irreg = `0`) |> 
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
    ) |> 
    # return participant, rule, orig conf, updated conf
    select(participant_id,rule,confidence,updated_confidence)
  
  # grab the posttest, only the best rules, join updated confidences across rules
  final_confidences = d |>
    filter(
      phase == 'posttest',
      reg_dist == 'reversed',
      best_rule_word_type
    ) |> 
    select(participant_id,word,rule,type,confidence) |>
    left_join(updated_confidences, by = join_by(participant_id, rule, confidence)) |> 
    # if the rule wasn't in the esp its confidence didn't change
    mutate(
      final_confidence = case_when(
        is.na(updated_confidence) ~ confidence,
        !is.na(updated_confidence) ~ updated_confidence
      )
    ) |> 
    # for each participant and word, we have two final confidences: from best regular and best irregular rule. this confidence either changed in the esp phase or it didn't because the rule wasn't called in the esp.
    select(participant_id,word,type,final_confidence)
  
  # we calc weights based on final confidences
  final_weights = final_confidences |>
    pivot_wider(names_from = type, values_from = final_confidence, values_fill = 0) |> 
    mutate(updated_weight = case_when(
        irregular == 0 ~ 1,
        irregular != 0 ~ regular / (regular + irregular)
      )
    ) |> 
    select(-regular,-irregular)
  
  # we grab the posttest again and add weights. since d has double rows, we need to distinct for the relevant cols.
  reversed_posttest = d |>
    filter(
      phase == 'posttest',
      reg_dist == 'reversed'
    ) |> 
    distinct(participant_id,word,weight,resp_reg) |>  # !!! and how
    left_join(final_weights, by = join_by(participant_id, word))
  
  # we calc somers c
  reversed_posttest = reversed_posttest |> 
    mutate(
      c = Hmisc::somers2(updated_weight, resp_reg)[1]
    )
  
  return(reversed_posttest)
}

# -- read -- #

d = read_tsv('dat/exp_data_with_rules.gz') # data w/ rules
test2 = read_tsv('dat/posttest_data_original.gz') # original posttest

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
  learning_rate = seq(.5,25,.5),
  which_rules = c('both','regular','irregular'),
  which_responses = c('coplayer','own')
)

# iterate the learner through the parameter settings
# calc somers C
outcomes = parameters |>
  rowwise() |> 
  mutate(
    out = list(updateConfidence(learning_rate, which_rules, which_responses))
  )

outcomes_curve = outcomes |> 
  unnest(out) |> 
  distinct(which_rules, which_responses, learning_rate, c)

best_outcomes = outcomes |> 
  unnest(out) |> 
  group_by(which_rules, which_responses) |> 
  filter(c == max(c)) |> 
  ungroup()

# -- combine with test2 data -- #

best_settings = best_outcomes |> 
  filter(c == max(c)) |> 
  distinct(learning_rate,which_rules,which_responses)

best_preds = outcomes |> 
  inner_join(best_settings) |> 
  unnest(out) |> 
  rename(baseline_mgl_features_updating = updated_weight) |>  # !!!
  select(participant_id,word,baseline_mgl_features_updating)

test2_2 = test2 |> 
  filter(lex_typicality == 'atypical') |> 
  left_join(best_preds)

# -- write -- #

write_tsv(best_outcomes, 'dat/modelling_best_outcomes.tsv')
write_tsv(outcomes_curve, 'dat/modelling_curve.tsv')
write_tsv(test2_2, 'dat/posttest_data_original_with_best_rules.gz')
