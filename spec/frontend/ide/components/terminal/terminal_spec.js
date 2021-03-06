import { createLocalVue, shallowMount } from '@vue/test-utils';
import Vuex from 'vuex';
import { GlLoadingIcon } from '@gitlab/ui';
import Terminal from '~/ide/components/terminal/terminal.vue';
import TerminalControls from '~/ide/components/terminal/terminal_controls.vue';
import {
  STARTING,
  PENDING,
  RUNNING,
  STOPPING,
  STOPPED,
} from '~/ide/stores/modules/terminal/constants';
import GLTerminal from '~/terminal/terminal';

const TEST_TERMINAL_PATH = 'terminal/path';

const localVue = createLocalVue();
localVue.use(Vuex);

jest.mock('~/terminal/terminal', () =>
  jest.fn().mockImplementation(() => ({
    dispose: jest.fn(),
    disable: jest.fn(),
    addScrollListener: jest.fn(),
    scrollToTop: jest.fn(),
    scrollToBottom: jest.fn(),
  })),
);

describe('IDE Terminal', () => {
  let wrapper;
  let state;

  const factory = propsData => {
    const store = new Vuex.Store({
      state,
      mutations: {
        set(prevState, newState) {
          Object.assign(prevState, newState);
        },
      },
    });

    wrapper = shallowMount(localVue.extend(Terminal), {
      propsData: {
        status: RUNNING,
        terminalPath: TEST_TERMINAL_PATH,
        ...propsData,
      },
      localVue,
      store,
    });
  };

  beforeEach(() => {
    state = {
      panelResizing: false,
    };
  });

  afterEach(() => {
    wrapper.destroy();
  });

  describe('loading text', () => {
    [STARTING, PENDING].forEach(status => {
      it(`shows when starting (${status})`, () => {
        factory({ status });

        expect(wrapper.find(GlLoadingIcon).exists()).toBe(true);
        expect(wrapper.find('.top-bar').text()).toBe('Starting...');
      });
    });

    it(`shows when stopping`, () => {
      factory({ status: STOPPING });

      expect(wrapper.find(GlLoadingIcon).exists()).toBe(true);
      expect(wrapper.find('.top-bar').text()).toBe('Stopping...');
    });

    [RUNNING, STOPPED].forEach(status => {
      it('hides when not loading', () => {
        factory({ status });

        expect(wrapper.find(GlLoadingIcon).exists()).toBe(false);
        expect(wrapper.find('.top-bar').text()).toBe('');
      });
    });
  });

  describe('refs.terminal', () => {
    it('has terminal path in data', () => {
      factory();

      expect(wrapper.vm.$refs.terminal.dataset.projectPath).toBe(TEST_TERMINAL_PATH);
    });
  });

  describe('terminal controls', () => {
    beforeEach(() => {
      factory();
      wrapper.vm.createTerminal();

      return localVue.nextTick();
    });

    it('is visible if terminal is created', () => {
      expect(wrapper.find(TerminalControls).exists()).toBe(true);
    });

    it('scrolls glterminal on scroll-up', () => {
      wrapper.find(TerminalControls).vm.$emit('scroll-up');

      expect(wrapper.vm.glterminal.scrollToTop).toHaveBeenCalled();
    });

    it('scrolls glterminal on scroll-down', () => {
      wrapper.find(TerminalControls).vm.$emit('scroll-down');

      expect(wrapper.vm.glterminal.scrollToBottom).toHaveBeenCalled();
    });

    it('has props set', () => {
      expect(wrapper.find(TerminalControls).props()).toEqual({
        canScrollUp: false,
        canScrollDown: false,
      });

      wrapper.setData({ canScrollUp: true, canScrollDown: true });

      return localVue.nextTick().then(() => {
        expect(wrapper.find(TerminalControls).props()).toEqual({
          canScrollUp: true,
          canScrollDown: true,
        });
      });
    });
  });

  describe('refresh', () => {
    let createTerminal;
    let stopTerminal;

    beforeEach(() => {
      createTerminal = jest.fn().mockName('createTerminal');
      stopTerminal = jest.fn().mockName('stopTerminal');
    });

    it('creates the terminal if running', () => {
      factory({ status: RUNNING, terminalPath: TEST_TERMINAL_PATH });

      wrapper.setMethods({ createTerminal });
      wrapper.vm.refresh();

      expect(createTerminal).toHaveBeenCalled();
    });

    it('stops the terminal if stopping', () => {
      factory({ status: STOPPING });

      wrapper.setMethods({ stopTerminal });
      wrapper.vm.refresh();

      expect(stopTerminal).toHaveBeenCalled();
    });
  });

  describe('createTerminal', () => {
    beforeEach(() => {
      factory();
      wrapper.vm.createTerminal();
    });

    it('creates the terminal', () => {
      expect(GLTerminal).toHaveBeenCalledWith(wrapper.vm.$refs.terminal);
      expect(wrapper.vm.glterminal).toBeTruthy();
    });

    describe('scroll listener', () => {
      it('has been called', () => {
        expect(wrapper.vm.glterminal.addScrollListener).toHaveBeenCalled();
      });

      it('updates scroll data when called', () => {
        expect(wrapper.vm.canScrollUp).toBe(false);
        expect(wrapper.vm.canScrollDown).toBe(false);

        const listener = wrapper.vm.glterminal.addScrollListener.mock.calls[0][0];
        listener({ canScrollUp: true, canScrollDown: true });

        expect(wrapper.vm.canScrollUp).toBe(true);
        expect(wrapper.vm.canScrollDown).toBe(true);
      });
    });
  });

  describe('destroyTerminal', () => {
    it('calls dispose', () => {
      factory();
      wrapper.vm.createTerminal();
      const disposeSpy = wrapper.vm.glterminal.dispose;

      expect(disposeSpy).not.toHaveBeenCalled();

      wrapper.vm.destroyTerminal();

      expect(disposeSpy).toHaveBeenCalled();
      expect(wrapper.vm.glterminal).toBe(null);
    });
  });

  describe('stopTerminal', () => {
    it('calls disable', () => {
      factory();
      wrapper.vm.createTerminal();

      expect(wrapper.vm.glterminal.disable).not.toHaveBeenCalled();

      wrapper.vm.stopTerminal();

      expect(wrapper.vm.glterminal.disable).toHaveBeenCalled();
    });
  });
});
