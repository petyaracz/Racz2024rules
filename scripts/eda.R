# eda

setwd('~/Github/Racz2024c')

library(tidyverse)
library(magrittr)
library(glue)
library(broom)
library(patchwork)
library(ggthemes)

# -- fun -- #

# -- read -- #

b = read_tsv('dat/mgl_weights.tsv')
d = read_tsv('dat/exp_data_tidy.tsv')

# -- factor levels -- #

## sort out factor levels
d %<>%
  mutate(
    phase = factor(phase, levels = c('test1', 'esp', 'test2')),
    reg_rate = factor(reg_rate, levels = c('-40%', 'nc', '+40%')),
    lex_typicality = factor(lex_typicality, levels = c('random', 'atypical', 'typical'))
  )

w = b %>%
  select(word,regular,irregular,weight)

l = w %>% 
  pivot_longer(c(regular,irregular)) %>% 
  group_by(name) %>% 
  mutate(scaled_value = scales::rescale(value)) %>% 
  ungroup()

avgs = d %>% 
  count(word,phase,reg_rate,lex_typicality,resp_reg) %>% 
  pivot_wider(names_from = resp_reg, values_from = n, values_fill = 0) %>% 
  mutate(test_log_odds = log((`1`+1)/(`0`+1))) %>% 
  select(-`0`,-`1`)

# -- main -- #

# rule weights #

## baseline
p_b_w = b %>% 
  ggplot(aes(weight,baseline_log_odds_regular)) +
  geom_point(alpha = .5) +
  theme_bw() +
  geom_smooth(method = 'loess') +
  geom_smooth(method = 'lm', lty = 3, se = F, colour = 'darkgrey') +
  ggtitle('baseline data') +
  xlab('MGL: best regular rule conf /\n(best reg conf + best irreg conf)') +
  ylab('log regular / irregular') +
  ggtitle('baseline')

## pre-test
p_t1_w = avgs %>% 
  filter(phase == 'test1') %>% 
  left_join(w) %>%
  ggplot(aes(weight,test_log_odds)) +
  geom_point(alpha = .5) +
  geom_smooth(method = 'loess') +
  theme_bw() +
  xlab('MGL: best regular rule conf /\n(best reg conf + best irreg conf)') +
  ylab('log regular / irregular') +
  ggtitle('pretest')

## post-test
p_t2_w = avgs %>% 
  filter(phase == 'test2') %>% 
  left_join(w) %>%
  ggplot(aes(weight,test_log_odds, colour = lex_typicality)) +
  geom_point(alpha = .5) +
  geom_smooth(method = 'loess') +
  theme_bw() +
  facet_wrap( ~ reg_rate) +
  scale_colour_viridis_d(option = 'E') +
  xlab('MGL: best regular rule conf /\n(best reg conf + best irreg conf)') +
  ylab('log regular / irregular') +
  ggtitle('posttest')
  
# best rules #

## baseline
p_b_r = b %>% 
  select(word,baseline_log_odds_regular) %>% 
  left_join(l) %>% 
  ggplot(aes(scaled_value,baseline_log_odds_regular,colour=name)) +
  geom_point(alpha = .5) +
  theme_bw() +
  geom_smooth(method = 'loess') +
  geom_smooth(method = 'lm', lty = 3, se = F, colour = 'darkgrey') +
  ggtitle('baseline data') +
  xlab('MGL: best regular rule conf /\n(best reg conf + best irreg conf)') +
  ylab('log regular / irregular') +
  scale_colour_viridis_d(option = 'D') +
  ggtitle('baseline')

## pre-test
p_t1_r = avgs %>% 
  filter(phase == 'test1') %>% 
  left_join(l) %>% 
  ggplot(aes(scaled_value,test_log_odds, colour = name)) +
  geom_point(alpha = .5) +
  geom_smooth(method = 'loess') +
  theme_bw() +
  facet_wrap( ~ reg_rate + lex_typicality, ncol = 3) +
  scale_colour_viridis_d(option = 'D') +
  xlab('MGL: best regular rule conf /\n(best reg conf + best irreg conf)') +
  ylab('log regular / irregular') +
  ggtitle('pretest')

## post-test
p_t2_r = avgs %>% 
  filter(phase == 'test2') %>% 
  left_join(l) %>% 
  ggplot(aes(scaled_value,test_log_odds, colour = name)) +
  geom_point(alpha = .5) +
  geom_smooth(method = 'loess') +
  theme_bw() +
  facet_wrap( ~ lex_typicality, ncol = 3) +
  scale_colour_viridis_d(option = 'D') +
  xlab('MGL: best regular rule conf /\n(best reg conf + best irreg conf)') +
  ylab('log regular / irregular') +
  ggtitle('posttest')

# weight trajectory #

trials = d %>% 
  left_join(w) %>% 
  arrange(overall_index) %>% 
  group_by(overall_index,reg_rate,lex_typicality,phase,trial_index) %>% 
  nest()

estimates_trials = trials %>% 
  mutate(
    glm = map(data, ~
                glm(resp_reg ~ 1 + weight, family = binomial, data = .)
                ),
    tidy = map(glm, ~ tidy(., conf.int = T))
  ) %>% 
  select(-data,-glm) %>% 
  unnest(tidy) %>% 
  filter(
    term == 'weight',
    !overall_index %in% c(79,91) # silly fits
         )

p_e_w = estimates_trials %>% 
  filter(phase == 'esp') %>% 
  ggplot(aes(trial_index,statistic, colour = reg_rate)) +
  geom_point(alpha = .5) +
  geom_smooth(method = 'loess') +
  facet_wrap( ~ lex_typicality) +
  scale_colour_viridis_d(option = 'C') +
  theme_bw() +
  xlab('trial index') +
  ylab('figure out what this is and win a coconut') +
  ggtitle('esp')

# best rule trajectory #

trials2 = d %>% 
  left_join(l) %>% 
  arrange(overall_index) %>% 
  group_by(overall_index,reg_rate,lex_typicality,phase,trial_index,name) %>% 
  nest()

estimates_trials2 = trials2 %>% 
  mutate(
    glm = map(data, ~
                glm(resp_reg ~ 1 + scaled_value, family = binomial, data = .)
    ),
    tidy = map(glm, ~ tidy(., conf.int = T))
  ) %>% 
  select(-data,-glm) %>% 
  unnest(tidy) %>% 
  filter(
    term == 'scaled_value',
    # !overall_index %in% c(79,91) # silly fits
  ) %>% 
  mutate(abs_statistic = case_when(
      name == 'irregular' ~ -statistic,
      name == 'regular' ~ statistic
    )
  )

p_e_r = estimates_trials2 %>% 
  filter(phase == 'esp') %>%
  ggplot(aes(trial_index,abs_statistic, colour = name)) +
  geom_point(alpha = .5) +
  geom_smooth(method = 'loess') +
  facet_wrap( ~ reg_rate + lex_typicality) +
  scale_colour_viridis_d(option = 'D') +
  theme_bw() +
  xlab('trial index') +
  ylab('figure out what THIS is and win a coconut') +
  ggtitle('esp')

p_e_r2 = estimates_trials2 %>% 
  filter(phase == 'esp') %>%
  ggplot(aes(trial_index,abs_statistic, colour = name)) +
  geom_point(alpha = .5) +
  geom_smooth(method = 'loess') +
  facet_wrap( ~ lex_typicality) +
  scale_colour_viridis_d(option = 'D') +
  theme_bw() +
  xlab('trial index') +
  ylab('figure out what THIS is and win a coconut (abs)') +
  ggtitle('esp')

p_t2_w2 = avgs %>% 
  filter(phase == 'test2') %>% 
  left_join(b) %>% 
  ggplot(aes(baseline_log_odds_regular,test_log_odds,colour = lex_typicality)) +
  geom_point(alpha = .5) +
  geom_smooth(method = 'lm') +
  theme_bw() +
  scale_colour_viridis_d(option = 'C')

# combine

p1 = p_b_w | p_b_r
p2 = p_e_w / p_e_r2
p3 = p_t2_w / p_t2_r

p1 / p2 / p3 + plot_layout(heights = c(1,2,2))
ggsave('fig/fig1.pdf', width = 10, height = 15)
