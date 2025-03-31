# misc eda script

best_outcome = d |> 
  distinct(category,word) |> 
  inner_join(best_outcome)

rules_per_category = d |> 
  filter(best_rule_word_type) |> 
  distinct(category,type,rule,scope)

rules_per_category |> 
  arrange(-scope) |> 
  group_by(category,type) |> 
  slice(1) |> 
  select(category,type,scope) |> 
  pivot_wider(names_from = type, values_from = scope)

rules_per_category |> 
  ggplot(aes(category,log10(scope),colour = type)) +
  geom_jitter(width = .1)

best_outcome |> 
  ggplot() +
  geom_point(aes(weight,mean_reg), colour = 'lightgrey', alpha = .5) +
  geom_smooth(aes(weight,mean_reg), method = 'loess', colour = 'lightgrey') +
  geom_point(aes(updated_weight,mean_reg), colour = 'black', alpha = .5) +
  geom_smooth(aes(updated_weight,mean_reg,colour = as.factor(learning_rate)), method = 'loess', colour = 'black') +
  scale_colour_viridis_d(option = 'inferno') +
  theme_bw() +
  facet_wrap( ~ category)
