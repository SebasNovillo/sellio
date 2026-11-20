import base from '@sellio/eslint-config/base';

export default [...base, { ignores: ['src/generated/**', '.test-build/**'] }];
