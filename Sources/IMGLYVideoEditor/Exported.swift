// Fork: re-export IMGLYEditor (and transitively IMGLYCore / IMGLYCoreUI) so consumers that
// `import IMGLYVideoEditor` keep access to EngineSettings, OnCreate, etc. Upstream removed this
// during the 1.7x refactor; the fork restores it to preserve the public surface Loca depends on.
@_exported import IMGLYEditor
