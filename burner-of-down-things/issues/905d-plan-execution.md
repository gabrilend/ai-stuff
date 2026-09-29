# 905d — Plan execution

The fourth piece of 905.

## Current Behavior

A plan can be found and checked; nothing runs it.

## Intended Behavior

Running a plan executes each station in order, each result becoming a new
parcel that is recorded and handed to the next station.

## Suggested Implementation Steps

1. The run loop over a checked plan. 2. Recording each intermediate
   parcel. **Test:** a two-station plan runs end to end and every
   intermediate parcel is kept.

## Blocked by

- 905c
