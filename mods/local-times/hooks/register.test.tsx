import { expect, test } from 'claude-code/testing'

for (const surface of ['terminal', 'desktop'] as const) {
  test(
    `${surface}: the engine is handed the reply with the configured zone appended`,
    { options: { timeZone: 'Asia/Tokyo' } },
    async ($, on) => {
      const drawn: string[] = []
      on('ui.render', { component: 'AssistantMessage' }, ($, e) => {
        drawn.push(e.props.text)
        const { Text } = $.ui.resolve(e)
        return <Text>{e.props.text}</Text>
      })

      const ui = await $.ui.mount({
        plugin: 'local-times',
        surface,
        component: 'AssistantMessage',
        props: { text: 'Failed at 2026-11-19T18:04Z.', isFirstOfReply: true },
      })
      await ui.unmount()

      expect(drawn).toEqual(['Failed at 2026-11-19T18:04Z (Nov 20 at 3:04 AM GMT+9).'])
    },
  )
}
