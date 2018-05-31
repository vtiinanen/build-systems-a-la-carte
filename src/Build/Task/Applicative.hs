{-# LANGUAGE ConstraintKinds, RankNTypes, ScopedTypeVariables, TypeApplications #-}

-- | Applicative dependencies, as provided by @make@, @ninja@ etc.
--   Dependencies are known before any execution begins.
module Build.Task.Applicative (
    dependencies, inputs, partial, exceptional
    ) where

import Control.Applicative
import Data.Functor.Compose
import Data.Maybe
import Data.Proxy

import Build.Task
import Build.Task.Wrapped
import Build.Utilities

-- | The dependencies of a task.
dependencies :: Task Applicative k v -> [k]
dependencies task = getConst $ task (\k -> Const [k])

-- | Is this task an input.
isInput :: forall k v. Tasks Applicative k v -> k -> Bool
isInput tasks key = isNothing (tasks @Proxy key)

-- | Find all ultimate dependencies that go into this task.
inputs :: forall k v. Ord k => Tasks Applicative k v -> k -> [k]
inputs tasks = filter (isInput tasks) . reachable deps
  where
    deps :: k -> [k]
    deps = maybe [] (\task -> dependencies (unwrap @Applicative task)) . tasks

-- | Convert a task with a total lookup function @k -> m v@ into a task
-- with a partial lookup function @k -> m (Maybe v)@. This essentially lifts the
-- task from the type of values @v@ to @Maybe v@, where the result @Nothing@
-- indicates that the task failed because of a missing dependency.
-- Use 'debugPartial' if you need to know which dependency was missing.
partial :: Task Applicative k v -> Task Applicative k (Maybe v)
partial task fetch = getCompose $ task (Compose . fetch)

-- | Convert a task with a total lookup function @k -> m v@ into a task
-- with a lookup function that can throw exceptions @k -> m (Either e v)@. This
-- essentially lifts the task from the type of values @v@ to @Either e v@,
-- where the result @Left e@ indicates that the task failed because of a
-- failed dependency lookup, and @Right v@ yeilds the value otherwise.
exceptional :: Task Applicative k v -> Task Applicative k (Either e v)
exceptional task fetch = getCompose $ task (Compose . fetch)
