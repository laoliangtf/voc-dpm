function scores = get_scores_stats(pyra, model, trees)

% Get block scores used for computing cascade thresholds.
%
% pyra     feature pyramid
% model    object model
% info     detection info from gdetect.m

scores = zeros(model.numblocks, length(trees));
loc_f = loc_feat(model, pyra.num_levels);

for d = 1:length(trees)
  t = tree_mat_to_struct(trees{d});

  for j = 1:length(t)
    sym = t(j).symbol;
    if model.symbols(sym).type == 'T'
      % filter score
      fi = model.symbols(sym).filter;
      scores(:,d) = add_filter_score(model, scores(:,d),    ...
                                     t(j).x, t(j).y,        ...
                                     pyra.padx, pyra.pady,  ...
                                     t(j).ds, fi,           ...
                                     pyra.feat{t(j).l});
    else
      % deformation score
      ruleind = t(j).rule_index;
      if model.rules{sym}(ruleind).type == 'D'
        bl = model.rules{sym}(ruleind).def.blocklabel;
        dx = t(j).dx;
        dy = t(j).dy;
        def = [-(dx^2); -dx; -(dy^2); -dy];
        if model.rules{sym}(ruleind).def.flip
          def(2) = -def(2);
        end
        scores(bl,d) = scores(bl,d) + model.blocks(bl).w' * def;
      end
      % offset score
      bl = model.rules{sym}(ruleind).offset.blocklabel;
      scores(bl,d) = scores(bl,d) + model.blocks(bl).w * model.features.bias;
      % location/scale score
      bl = model.rules{sym}(ruleind).loc.blocklabel;
      l = t(j).l;
      scores(bl,d) = scores(bl,d) + model.blocks(bl).w' * loc_f(:,l);
    end
  end
  % Commented out because this check is not meaningful when passing in 
  % PCA features and filters
  %if abs(sum(scores(:,i)) - info(DET_VAL, model.start, i)) > 1e-10
  %  fprintf('%f ~= %f\n', sum(scores(:,i)), info(DET_VAL, model.start, i));
  %  error('wrong score');
  %end
end

scores = [sum(scores); scores];


%
% 
function scores = add_filter_score(model, scores, x, y, padx, pady, ds, fi, feat)

fsz = model.filters(fi).size;
% remove virtual padding
fy = y - pady*(2^ds-1);
fx = x - padx*(2^ds-1);
f = feat(fy:fy+fsz(1)-1, fx:fx+fsz(2)-1, :);

bl = model.filters(fi).blocklabel;
if model.filters(fi).flip
  scores(bl) = scores(bl) + model.blocks(bl).w_flipped(:)' * f(:);
else
  scores(bl) = scores(bl) + model.blocks(bl).w(:)' * f(:);
end
