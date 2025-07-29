export const fileLineCodequality = (file, line, codequalityData) => {
  const fileDiff = codequalityData?.files?.[file] || [];
  const lineDiff = fileDiff.filter((violation) => violation.line === line);
  return lineDiff;
};

// Returns the SAST degradations for a specific line of a given file
export const fileLineSast = (file, line, sastData) => {
  const lineDiff = [];

  sastData?.added?.map((e) => {
    const startLine = parseInt(e.location.startLine, 10);
    if (e.location.file === file && startLine === line) {
      lineDiff.push({
        line: startLine,
        description: e.description,
        details: e.details,
        severity: e.severity.toLowerCase(),
        location: e.location,
        foundByPipelineIid: e.foundByPipelineIid,
        identifiers: e.identifiers,
        state: e.state.toLowerCase(),
        title: e.title,
      });
    }
    return e;
  });
  return lineDiff;
};
