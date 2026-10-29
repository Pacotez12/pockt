import { column, Schema, Table } from '@powersync/web';

export const AppSchema = new Schema({
  spike_tx: new Table({
    user_id: column.text,
    amount: column.integer,
    note: column.text,
    occurred_at: column.integer,
    updated_at: column.integer,
    deleted_at: column.integer,
  }),
});

export type SpikeTx = (typeof AppSchema.types)['spike_tx'];
