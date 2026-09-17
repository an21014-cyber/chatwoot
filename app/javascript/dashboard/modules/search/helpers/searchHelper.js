import ContactAPI from 'dashboard/api/contacts';

export const DATE_RANGE_TYPES = {
  LAST_7_DAYS: 'last_7_days',
  LAST_30_DAYS: 'last_30_days',
  LAST_60_DAYS: 'last_60_days',
  LAST_90_DAYS: 'last_90_days',
  CUSTOM: 'custom',
  BETWEEN: 'between',
};

export const generateURLParams = (
  { from, in: inboxId, dateRange, status },
  isAdvancedSearchEnabled = true
) => {
  const params = {};

  // Status is a plain DB filter, not part of the paid advanced_search
  // feature, so it applies regardless of that flag.
  if (status) params.status = status;

  // Only include filter params if advanced search is enabled
  if (isAdvancedSearchEnabled) {
    if (from) params.from = from;
    if (inboxId) params.inbox_id = inboxId;

    if (dateRange?.type) {
      const { type, from: dateFrom, to: dateTo } = dateRange;
      params.range = type;

      if (dateFrom) params.since = dateFrom;
      if (dateTo) params.until = dateTo;
    }
  }

  return params;
};

export const parseURLParams = (query, isAdvancedSearchEnabled = true) => {
  const status = query.status || null;

  // If advanced search is disabled, return empty filters (status still applies)
  if (!isAdvancedSearchEnabled) {
    return {
      from: null,
      in: null,
      dateRange: {
        type: null,
        from: null,
        to: null,
      },
      status,
    };
  }

  const { from, inbox_id, since, until, range } = query;

  let type = range;
  if (!type && (since || until)) {
    type = DATE_RANGE_TYPES.BETWEEN;
  }

  return {
    from: from || null,
    in: inbox_id ? Number(inbox_id) : null,
    dateRange: {
      type,
      from: since ? Number(since) : null,
      to: until ? Number(until) : null,
    },
    status,
  };
};

export const fetchContactDetails = async id => {
  try {
    const response = await ContactAPI.show(id);
    return response.data.payload;
  } catch (error) {
    // error
    return null;
  }
};
