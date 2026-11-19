import type { Register } from 'claude-code'
import { annotateUtcTimes, systemTimeZone } from './annotate'

export const register: Register = (on, options) => {
  const configured = typeof options.timeZone === 'string' ? options.timeZone.trim() : ''
  const timeZone = configured || systemTimeZone()

  // Changes only what is drawn: the stored reply, and what the model reads back, stay in UTC.
  on('ui.render', { component: 'AssistantMessage' }, ($, e, next) => {
    const text = annotateUtcTimes(e.props.text, timeZone)
    return text === e.props.text ? next(e) : next({ ...e, props: { ...e.props, text } })
  })
}
