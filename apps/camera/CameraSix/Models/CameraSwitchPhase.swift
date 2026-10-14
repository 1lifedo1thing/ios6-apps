enum CameraSwitchPhase {
  case idle, closing, changing, opening
}

struct CameraSwitchResult {
  let front: Bool
  let succeeded: Bool
}
