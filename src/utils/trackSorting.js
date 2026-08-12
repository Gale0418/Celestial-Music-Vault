export function sortTracksWithOriginalIndex(tracks, sortKey = 'default', sortDirection = 'asc') {
  const direction = sortDirection === 'desc' ? -1 : 1;
  return (Array.isArray(tracks) ? tracks : [])
    .map((track, originalIndex) => ({ ...track, originalIndex }))
    .sort((a, b) => {
      if (sortKey === 'default') return (a.originalIndex - b.originalIndex) * direction;

      const valueA = typeof a[sortKey] === 'string' ? a[sortKey].toLocaleLowerCase() : '';
      const valueB = typeof b[sortKey] === 'string' ? b[sortKey].toLocaleLowerCase() : '';
      return valueA.localeCompare(valueB, 'zh-Hant') * direction;
    });
}
