/*
 * 046-metrics.h — measurements, written down where the documentation
 * builder can find them.
 *
 * General description: every test and demo that measures something calls
 * metric_record with a stable name, a number, a unit, and the name of the
 * paragraph in the documentation that explains what the number means. The
 * records land as one tab-separated line each in
 * tmp/shared-memory/metrics/<program>.tsv. The documentation pages are
 * built from those files later, by a separate tool that knows nothing
 * about how the numbers were produced — gathering and showing are kept
 * apart, so a wrong number is either a gathering bug or a showing bug and
 * never a tangle of both.
 *
 * Line format (one per metric; later lines with the same name replace
 * earlier ones when the pages are built):
 *   name <TAB> value <TAB> unit <TAB> explanation-anchor <TAB> short description
 */
#ifndef SOREN_METRICS_H
#define SOREN_METRICS_H

/* Name the program the records belong to; opens (truncates) its file.
 * The directory comes from SOREN_METRICS_DIR, or <project>/tmp/shared-
 * memory/metrics when that is unset. */
void metrics_open(const char *program);

void metric_record(const char *name, double value, const char *unit,
                   const char *anchor, const char *description);

void metrics_close(void);

#endif
