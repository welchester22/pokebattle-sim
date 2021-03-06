@ALL_GENERATIONS = [ 'rb', 'gs', 'rs', 'dp', 'bw', 'xy' ]
@SUPPORTED_GENERATIONS = [ 'bw', 'xy' ]
@DEFAULT_GENERATION = 'xy'

@INT_TO_GENERATION = {}
for gen, i in @ALL_GENERATIONS
  @INT_TO_GENERATION[i + 1] = gen

@GENERATION_TO_INT = {}
for gen, i in @ALL_GENERATIONS
  @GENERATION_TO_INT[gen] = (i + 1)
