# fit hierarchical models using gcm, mgl, our new mgl predictions, on reversed post-test data. compare models. save everything.

# -- head -- #

setwd('~/Github/Racz2024rules/')

library(tidyverse)
library(rstanarm)
library(broom.mixed)
library(patchwork)

# -- read -- #

test2_2 = read_tsv('dat/posttest_data_original_with_best_rules.gz') # test2 with updating mgl preds

# unique(test2_2$lex_typicality)
# unique(test2_2$reg_rate)

# -- fit -- #

# baseline / individual: only corpus or test data as well
# edits / features: based on edit distance or uses phonological features

gcm1 = stan_glmer(resp_post_reg ~ baseline_gcm_features + (1|participant_id), family = binomial, data = test2_2, chains = 4, cores = 4)

gcm2 = stan_glmer(resp_post_reg ~ baseline_gcm_features + individual_gcm_features + (1|participant_id), family = binomial, data = test2_2, chains = 4, cores = 4)

mgl1 = stan_glmer(resp_post_reg ~ baseline_mgl_features + (1|participant_id), family = binomial, data = test2_2, chains = 4, cores = 4)

mgl2b = stan_glmer(resp_post_reg ~ baseline_mgl_features + individual_mgl_features + (1|participant_id), family = binomial, data = test2_2, chains = 4, cores = 4)

mgl2u = stan_glmer(resp_post_reg ~ baseline_mgl_features + baseline_mgl_features_updating + (1|participant_id), family = binomial, data = test2_2, chains = 4, cores = 4)

test2_2$`corpus-only learner` = test2_2$baseline_mgl_features
test2_2$`rule-building learner` = test2_2$individual_mgl_features
test2_2$`rule-updating learner` = test2_2$baseline_mgl_features_updating
mgl3 = stan_glmer(resp_post_reg ~ `corpus-only learner` + `rule-building learner` + `rule-updating learner` + (1|participant_id), family = binomial, data = test2_2, chains = 4, cores = 4)

# -- cv -- #

loo_gcm1 = loo(gcm1)
loo_gcm2 = loo(gcm2)
loo_mgl1 = loo(mgl1)
loo_mgl2b = loo(mgl2b)
loo_mgl2u = loo(mgl2u)
loo_mgl3 = loo(mgl3)

# -- check -- #

# though I think stan complains if the chains are bad
plot(gcm1, "rhat")
plot(gcm2, "rhat")
plot(mgl1, "rhat")
plot(mgl2b, "rhat")
plot(mgl2u, "rhat")
plot(mgl3, 'rhat')
pp_check(gcm1)
pp_check(gcm2)
pp_check(mgl1)
pp_check(mgl2b)
pp_check(mgl2u)
performance::check_collinearity(mgl3)

# -- compare -- #

loo_compare(loo_gcm1,loo_gcm2)
loo_compare(loo_mgl1,loo_mgl2b)
loo_compare(loo_mgl1,loo_mgl2u)
loo_compare(loo_gcm2,loo_mgl2b,loo_mgl2u)

tidy(gcm2, conf.int = T)
tidy(mgl2b, conf.int = T)
tidy(mgl2u, conf.int = T)

plot(mgl2b, 'areas', regex_pars = 'mgl') + 
  ggtitle('Corpus- and rule-building learner') +
  scale_y_discrete(labels = c('corpus-only\nlearner','rule-building\nlearner'))
plot(mgl2u, 'areas', regex_pars = 'mgl') + 
  ggtitle('Corpus- and rule-updating learner') +
  scale_y_discrete(labels = c('corpus-only\nlearner','rule-updating\nlearner'))

plot(mgl3, 'areas', regex_pars = 'learner') + ggtitle('Learner contributions to\npredicting post-test answers')
ggsave('figures/linear_model.png', dpi = 1200, width = 6, height = 3, bg = 'white')

# -- write -- #

save(gcm1, file = 'models/gcm1.rda')
save(gcm2, file = 'models/gcm2.rda')
save(mgl1, file = 'models/mgl1.rda')
save(mgl2b, file = 'models/mgl2b.rda')
save(mgl2u, file = 'models/mgl2u.rda')
save(mgl3, file = 'models/mgl3.rda')

save(loo_gcm1, file = 'models/loo_gcm1.rda')
save(loo_gcm2, file = 'models/loo_gcm2.rda')
save(loo_mgl1, file = 'models/loo_mgl1.rda')
save(loo_mgl2b, file = 'models/loo_mgl2b.rda')
save(loo_mgl3, file = 'models/loo_mgl3.rda')
save(loo_mgl2u, file = 'models/loo_mgl2u.rda')