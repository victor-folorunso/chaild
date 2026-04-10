import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const FLUTTERWAVE_SECRET_HASH = Deno.env.get('FLUTTERWAVE_SECRET_HASH') ?? ''

serve(async (req: Request) => {
  // Verify Flutterwave webhook signature
  const hash = req.headers.get('verif-hash')
  if (!hash || hash !== FLUTTERWAVE_SECRET_HASH) {
    return new Response('Unauthorized', { status: 401 })
  }

  let body: Record<string, unknown>
  try {
    body = await req.json()
  } catch {
    return new Response('Bad Request', { status: 400 })
  }

  const event = body['event'] as string | undefined
  const data = body['data'] as Record<string, unknown> | undefined

  if (!event || !data) {
    return new Response('Bad Request', { status: 400 })
  }

  const flutterwaveReference = data['reference'] as string | undefined
  if (!flutterwaveReference) {
    return new Response('Bad Request', { status: 400 })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )

  if (event === 'transfer.completed') {
    const { error } = await supabase
      .from('payouts')
      .update({ status: 'completed' })
      .eq('transfer_reference', flutterwaveReference)

    if (error) {
      console.error('payout-webhook: failed to mark completed', error)
      return new Response('Internal Server Error', { status: 500 })
    }
  } else if (event === 'transfer.failed') {
    const reason = (data['complete_message'] as string | undefined) ?? 'Transfer failed'
    const { error } = await supabase
      .from('payouts')
      .update({ status: 'failed', failure_reason: reason })
      .eq('transfer_reference', flutterwaveReference)

    if (error) {
      console.error('payout-webhook: failed to mark failed', error)
      return new Response('Internal Server Error', { status: 500 })
    }
  }
  // Silently ignore other event types

  return new Response(JSON.stringify({ received: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
})
