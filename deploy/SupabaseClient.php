<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

/**
 * Minimal Supabase / PostgREST client for the Nimiro backend.
 *
 * SECURITY CONTRACT
 * -----------------
 * - The service_role key is read from config (`.env`) and is NEVER returned,
 *   logged, or exposed through any API response.
 * - If the credentials are missing the client refuses to run rather than
 *   falling back to the public key.
 * - Only the tables whitelisted in config/supabase.php can be addressed.
 *
 * This class deliberately talks PostgREST over HTTP instead of raw Postgres,
 * so the backend needs no new PHP extension (pdo_pgsql is not installed) and
 * no inbound database port.
 */
class SupabaseClient
{
    private string $url;
    private string $key;
    private int $timeout;
    /** @var array<string,string> */
    private array $tables;

    public function __construct()
    {
        $this->url = rtrim((string) config('supabase.url'), '/');
        $this->key = (string) config('supabase.service_key');
        $this->timeout = (int) config('supabase.timeout', 20);
        $this->tables = (array) config('supabase.tables', []);

        if (! config('supabase.enabled', true)) {
            throw new RuntimeException('Supabase integration is disabled.');
        }

        if ($this->url === '' || $this->key === '') {
            throw new RuntimeException(
                'Supabase is not configured. Set SUPABASE_URL and SUPABASE_SERVICE_KEY in .env.'
            );
        }
    }

    public function isConfigured(): bool
    {
        return $this->url !== '' && $this->key !== '';
    }

    /**
     * Resolve a logical table name against the whitelist.
     */
    private function table(string $logical): string
    {
        if (! isset($this->tables[$logical])) {
            throw new RuntimeException("Supabase table '{$logical}' is not whitelisted.");
        }

        return $this->tables[$logical];
    }

    /**
     * Build the auth headers. Never logged.
     *
     * @param  array<string,string>  $extra
     * @return array<string,string>
     */
    private function headers(array $extra = []): array
    {
        return array_merge([
            'apikey' => $this->key,
            'Authorization' => 'Bearer ' . $this->key,
            'Content-Type' => 'application/json',
            'Accept' => 'application/json',
        ], $extra);
    }

    private function endpoint(string $logical, string $query = ''): string
    {
        $base = $this->url . '/rest/v1/' . $this->table($logical);

        return $query === '' ? $base : $base . '?' . $query;
    }

    /**
     * SELECT rows.
     *
     * @param  array<string,string|int>  $filters   column => value (eq)
     * @param  array<int,array{0:string,1:string,2:string|int}>  $operators
     * @return array<int,array<string,mixed>>
     */
    public function select(
        string $logical,
        array $filters = [],
        array $operators = [],
        string $select = '*',
        ?int $limit = null,
        string $order = 'id.desc'
    ): array {
        $parts = ['select=' . $select];

        foreach ($filters as $column => $value) {
            $parts[] = $column . '=eq.' . rawurlencode((string) $value);
        }

        foreach ($operators as [$column, $operator, $value]) {
            $parts[] = $column . '=' . $operator . '.' . rawurlencode((string) $value);
        }

        if ($order !== '') {
            $parts[] = 'order=' . $order;
        }

        if ($limit !== null) {
            $parts[] = 'limit=' . $limit;
        }

        $response = Http::withHeaders($this->headers())
            ->timeout($this->timeout)
            ->get($this->endpoint($logical, implode('&', $parts)));

        return $this->decode($response, 'select:' . $logical);
    }

    /**
     * SELECT a single row (or null).
     *
     * @param  array<string,string|int>  $filters
     * @return array<string,mixed>|null
     */
    public function first(string $logical, array $filters, string $select = '*'): ?array
    {
        $rows = $this->select($logical, $filters, [], $select, 1);

        return $rows[0] ?? null;
    }

    /**
     * INSERT one row (upsert on conflict).
     *
     * @param  array<string,mixed>  $row
     * @return array<int,array<string,mixed>>
     */
    public function upsert(string $logical, array $row, string $onConflict): array
    {
        $response = Http::withHeaders($this->headers([
            'Prefer' => 'resolution=merge-duplicates,return=representation',
        ]))
            ->timeout($this->timeout)
            ->post($this->endpoint($logical, 'on_conflict=' . rawurlencode($onConflict)), $row);

        return $this->decode($response, 'upsert:' . $logical);
    }

    /**
     * INSERT one row, ignoring duplicates.
     *
     * @param  array<string,mixed>  $row
     * @return array<int,array<string,mixed>>
     */
    public function insertIgnore(string $logical, array $row, string $onConflict): array
    {
        $response = Http::withHeaders($this->headers([
            'Prefer' => 'resolution=ignore-duplicates,return=representation',
        ]))
            ->timeout($this->timeout)
            ->post($this->endpoint($logical, 'on_conflict=' . rawurlencode($onConflict)), $row);

        return $this->decode($response, 'insert:' . $logical);
    }

    /**
     * UPDATE rows matching an equality filter.
     *
     * @param  array<string,mixed>  $values
     * @param  array<string,string|int>  $filters
     * @return array<int,array<string,mixed>>
     */
    public function update(string $logical, array $values, array $filters): array
    {
        $parts = [];
        foreach ($filters as $column => $value) {
            $parts[] = $column . '=eq.' . rawurlencode((string) $value);
        }

        $response = Http::withHeaders($this->headers(['Prefer' => 'return=representation']))
            ->timeout($this->timeout)
            ->patch($this->endpoint($logical, implode('&', $parts)), $values);

        return $this->decode($response, 'update:' . $logical);
    }

    /**
     * DELETE rows matching an equality filter.
     *
     * @param  array<string,string|int>  $filters
     */
    public function delete(string $logical, array $filters): void
    {
        $parts = [];
        foreach ($filters as $column => $value) {
            $parts[] = $column . '=eq.' . rawurlencode((string) $value);
        }

        $response = Http::withHeaders($this->headers())
            ->timeout($this->timeout)
            ->delete($this->endpoint($logical, implode('&', $parts)));

        if ($response->failed()) {
            Log::error('Supabase delete failed', [
                'table' => $logical,
                'status' => $response->status(),
            ]);
            throw new RuntimeException('Supabase delete failed with status ' . $response->status());
        }
    }

    /**
     * @return array<int,array<string,mixed>>
     */
    private function decode($response, string $context): array
    {
        if ($response->failed()) {
            // Never log the key or the request headers.
            Log::error('Supabase request failed', [
                'context' => $context,
                'status' => $response->status(),
            ]);
            throw new RuntimeException('Supabase request failed with status ' . $response->status());
        }

        $decoded = $response->json();

        if (! is_array($decoded)) {
            return [];
        }

        // A single-object response (e.g. Accept: application/vnd.pgrst.object)
        // would decode as an associative array; normalise it to a list.
        return array_is_list($decoded) ? $decoded : [$decoded];
    }
}
