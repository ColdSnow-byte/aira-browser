import { useEffect, useState } from 'react';
import { listPhoneTabs } from '@/features/device-tabs/deviceTabsClient';
import type { CrossDeviceTabDevice } from '@/features/device-tabs/deviceTabsModels';

export function useChromeOtherDeviceTabs(active: boolean) {
  const [devices, setDevices] = useState<CrossDeviceTabDevice[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!active) return undefined;
    let disposed = false;
    setLoading(true);
    setError('');
    void listPhoneTabs()
      .then((list) => {
        if (disposed) return;
        setDevices(list.devices.filter((device) => device.tabs.length > 0));
        setLoading(false);
      })
      .catch((caught: unknown) => {
        if (disposed) return;
        setDevices([]);
        setError(String((caught as Error)?.message || caught || ''));
        setLoading(false);
      });
    return () => {
      disposed = true;
    };
  }, [active]);

  return { devices, loading, error };
}
