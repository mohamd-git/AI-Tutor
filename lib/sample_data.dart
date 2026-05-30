import 'models/lesson.dart';

// Temporary sample so we can see the rich lesson look without using the AI.
// This file gets deleted later once saved lessons exist.
const LessonSet sampleLessonSet = LessonSet(
  sourceName: 'Biology — Chapter 3 (sample)',
  topics: [
    Topic(
      title: 'What is a cell?',
      summary: 'The smallest living building block of every living thing.',
      explanation:
          'A cell is the smallest unit of life. That means it is the tiniest '
          'thing that is truly alive on its own. Think of a cell like a single '
          'brick. A house is built from many bricks, and in the same way your '
          'body is built from trillions of cells. Some living things, like '
          'bacteria, are just one single cell. Bigger living things, like '
          'plants, animals, and you, are made of many cells working together. '
          'Cells are far too small to see with your eyes, so scientists use a '
          'microscope to look at them.',
      terms: [
        TermDef(
            term: 'Cell',
            definition: 'the smallest living unit that can do life on its own'),
        TermDef(
            term: 'Organism',
            definition: 'any living thing, made of one cell or many cells'),
      ],
      question: QuizQuestion(
        question: 'What is the smallest unit of life?',
        options: ['An atom', 'A cell', 'An organ', 'A molecule'],
        answerIndex: 1,
        explanation: 'A cell is the smallest thing that is alive on its own.',
      ),
      youtubeQuery: 'what is a cell biology for beginners',
    ),
    Topic(
      title: 'Measuring cells (magnification)',
      summary:
          'Cells are tiny, so we use a microscope and a simple formula to '
          'measure how much bigger the image is.',
      explanation:
          'Because cells are so small, we look at them through a microscope, '
          'which makes them appear much bigger. The number of times bigger the '
          'image looks is called the magnification. We can work it out with an '
          'easy formula: divide the size of the image by the real size of the '
          'object. If you keep the units the same, the answer tells you how '
          'many times the microscope enlarged the cell.',
      terms: [
        TermDef(
            term: 'Magnification',
            definition:
                'how many times bigger the image looks than the real thing'),
      ],
      equations: [
        EquationItem(
          formula: 'magnification = image size / actual size',
          meaning:
              'Divide how big the picture is by how big the real object is. '
              'Example: if the image is 10 mm and the real cell is 1 mm, the '
              'magnification is 10 times.',
        ),
      ],
      question: QuizQuestion(
        question: 'An image is 20 mm. The real cell is 2 mm. What is the magnification?',
        options: ['2 times', '10 times', '40 times', '22 times'],
        answerIndex: 1,
        explanation: '20 divided by 2 equals 10, so it is 10 times bigger.',
      ),
      youtubeQuery: 'microscope magnification formula explained',
    ),
    Topic(
      title: 'Parts of a cell',
      summary: 'The membrane, nucleus, and cytoplasm each have a clear job.',
      explanation:
          'A cell has a few important parts, and each one has a job. The '
          'membrane is like a thin skin or wall around the cell. It decides '
          'what is allowed in and out. The nucleus is the control center, like '
          'the manager or boss, and it holds the instructions called DNA. The '
          'cytoplasm is the jelly that fills the cell, where most of the work '
          'happens and the parts float around.',
      terms: [
        TermDef(
            term: 'Membrane',
            definition: 'the outer wall that controls what goes in and out'),
        TermDef(
            term: 'Nucleus',
            definition: 'the control center that holds the DNA instructions'),
        TermDef(
            term: 'Cytoplasm',
            definition: 'the jelly inside where the work happens'),
      ],
      question: QuizQuestion(
        question: 'Which part is the control center of the cell?',
        options: ['Membrane', 'Cytoplasm', 'Nucleus', 'Wall'],
        answerIndex: 2,
        explanation: 'The nucleus holds the instructions and acts as the boss.',
      ),
      youtubeQuery: 'parts of a cell explained simply',
      chart: ChartData(
        type: 'pie',
        title: 'What a cell is mostly made of (%)',
        labels: ['Water', 'Protein', 'Other'],
        values: [70.0, 18.0, 12.0],
      ),
    ),
  ],
);
