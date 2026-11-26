import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { parseEnv } from 'node:util';

// Parse without populating process.env; only explicitly selected keys are returned.
export function readEnvironmentFiles(
  directory: string,
  filenames: readonly string[],
  keys: readonly string[],
  environment: NodeJS.ProcessEnv,
): Record<string, string> {
  const values: Record<string, string> = {};
  for (const filename of filenames) {
    let parsed: Record<string, string | undefined>;
    try {
      parsed = parseEnv(readFileSync(join(directory, filename), 'utf8'));
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') continue;
      throw new Error('Unable to read local environment configuration.');
    }
    for (const key of keys) {
      if (values[key] === undefined && parsed[key] !== undefined) values[key] = parsed[key];
    }
  }
  for (const key of keys) {
    if (environment[key] !== undefined) values[key] = environment[key];
  }
  return values;
}
